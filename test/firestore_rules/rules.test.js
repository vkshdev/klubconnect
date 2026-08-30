/*** Firestore Security Rules Unit Tests
 *

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'klubconnect-rules-test';
const RULES_PATH = path.resolve(__dirname, '../../firestore.rules');

describe('KlubConnect Firestore Security Rules Tests', () => {
  let testEnv;

  before(async () => {
    const rules = fs.readFileSync(RULES_PATH, 'utf8');
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: { rules },
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  describe('Multi-Tenant Isolation', () => {
    it('denies user from tenant A from reading documents of tenant B', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('users').doc('student_b').set({
          uid: 'student_b',
          institution_id: 'inst_mit',
          college_name: 'MIT',
          user_type: 'student',
        });
      });

      const aliceDb = testEnv.authenticatedContext('student_a', {
        institution_id: 'inst_stanford',
        college_name: 'Stanford',
      }).firestore();

      await assertFails(aliceDb.collection('users').doc('student_b').get());
    });
  });

  describe('Privilege Escalation Lockdown', () => {
    it('forbids a student from self-elevating user_type to faculty', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('users').doc('student_1').set({
          uid: 'student_1',
          institution_id: 'inst_mit',
          college_name: 'MIT',
          user_type: 'student',
          first_name: 'Alex',
        });
      });

      const studentDb = testEnv.authenticatedContext('student_1', {
        institution_id: 'inst_mit',
        college_name: 'MIT',
      }).firestore();

      // Attempting to change user_type to faculty should fail
      await assertFails(
        studentDb.collection('users').doc('student_1').update({
          user_type: 'faculty',
        })
      );
    });

    it('allows a user to update allowed profile fields (name, about, phone)', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('users').doc('student_1').set({
          uid: 'student_1',
          institution_id: 'inst_mit',
          college_name: 'MIT',
          user_type: 'student',
          first_name: 'Alex',
          about: 'CS Student',
        });
      });

      const studentDb = testEnv.authenticatedContext('student_1', {
        institution_id: 'inst_mit',
        college_name: 'MIT',
      }).firestore();

      await assertSucceeds(
        studentDb.collection('users').doc('student_1').update({
          about: 'CS Senior Student',
          phone_number: '+1234567890',
        })
      );
    });
  });

  describe('RSVP Enum Validation', () => {
    it('permits valid RSVP responses (attending, interested, not_going)', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('events').doc('evt_hackathon').set({
          event_id: 'evt_hackathon',
          club_id: 'club_cs',
          institution_id: 'inst_mit',
          college_name: 'MIT',
        });
        await db.collection('clubs').doc('club_cs').set({
          club_id: 'club_cs',
          institution_id: 'inst_mit',
          college_name: 'MIT',
        });
      });

      const studentDb = testEnv.authenticatedContext('student_1', {
        institution_id: 'inst_mit',
        college_name: 'MIT',
      }).firestore();

      await assertSucceeds(
        studentDb.collection('events').doc('evt_hackathon').collection('rsvps').doc('student_1').set({
          user_id: 'student_1',
          response: 'attending',
        })
      );
    });

    it('rejects invalid RSVP responses', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('events').doc('evt_hackathon').set({
          event_id: 'evt_hackathon',
          club_id: 'club_cs',
          institution_id: 'inst_mit',
          college_name: 'MIT',
        });
        await db.collection('clubs').doc('club_cs').set({
          club_id: 'club_cs',
          institution_id: 'inst_mit',
          college_name: 'MIT',
        });
      });

      const studentDb = testEnv.authenticatedContext('student_1', {
        institution_id: 'inst_mit',
        college_name: 'MIT',
      }).firestore();

      await assertFails(
        studentDb.collection('events').doc('evt_hackathon').collection('rsvps').doc('student_1').set({
          user_id: 'student_1',
          response: 'super_excited', // Invalid enum
        })
      );
    });
  });
});
