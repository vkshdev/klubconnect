/**
 * KlubConnect Firestore Security Rules Comprehensive Unit Test Suite
 *
 * Verifies multi-tenant isolation, privilege escalation lockdown,
 * cross-user tampering denial, faculty account status gating,
 * audit log immutability, RSVP enum validation, and storage asset rules.
 */

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');

const PROJECT_ID = 'klubconnect-rules-test';
const RULES_PATH = path.resolve(__dirname, '../../firestore.rules');

describe('KlubConnect Firestore Security Rules Comprehensive Test Suite', () => {
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

  // Helper function to seed user document
  async function seedUser(userData) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('users').doc(userData.uid).set(userData);
    });
  }

  // Helper function to seed club document
  async function seedClub(clubData) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('clubs').doc(clubData.club_id).set(clubData);
    });
  }

  // Helper function to seed event document
  async function seedEvent(eventData) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('events').doc(eventData.event_id).set(eventData);
    });
  }

  // Helper function to seed audit log document
  async function seedAuditLog(logData) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('audit_logs').doc(logData.audit_log_id).set(logData);
    });
  }

  // Helper function to seed storage asset document
  async function seedStorageAsset(assetData) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await db.collection('storage_assets').doc(assetData.asset_id).set(assetData);
    });
  }

  // =========================================================================
  // 1. Multi-Tenant Isolation Tests
  // =========================================================================
  describe('1. Multi-Tenant Isolation', () => {
    beforeEach(async () => {
      // Seed users from MIT and Stanford
      await seedUser({
        uid: 'alice_mit',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'student',
        first_name: 'Alice',
      });
      await seedUser({
        uid: 'bob_mit',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'student',
        first_name: 'Bob',
      });
      await seedUser({
        uid: 'charlie_stanford',
        institution_id: 'inst_stanford',
        college_name: 'Stanford',
        user_type: 'student',
        first_name: 'Charlie',
      });

      // Seed clubs
      await seedClub({
        club_id: 'club_mit_robotics',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        club_master_id: 'faculty_mit',
        name: 'MIT Robotics',
      });
      await seedClub({
        club_id: 'club_stanford_ai',
        institution_id: 'inst_stanford',
        college_name: 'Stanford',
        club_master_id: 'faculty_stanford',
        name: 'Stanford AI',
      });

      // Seed events
      await seedEvent({
        event_id: 'evt_mit_hackathon',
        club_id: 'club_mit_robotics',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        title: 'MIT Hackathon',
      });
      await seedEvent({
        event_id: 'evt_stanford_summit',
        club_id: 'club_stanford_ai',
        institution_id: 'inst_stanford',
        college_name: 'Stanford',
        title: 'Stanford AI Summit',
      });

      // Seed audit logs
      await seedAuditLog({
        audit_log_id: 'log_mit_1',
        institution_id: 'inst_mit',
        actor_user_id: 'alice_mit',
        action: 'user_login',
      });
      await seedAuditLog({
        audit_log_id: 'log_stanford_1',
        institution_id: 'inst_stanford',
        actor_user_id: 'charlie_stanford',
        action: 'user_login',
      });
    });

    it('allows a user to read other user documents in the same institution', async () => {
      const aliceDb = testEnv.authenticatedContext('alice_mit', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(aliceDb.collection('users').doc('bob_mit').get());
    });

    it('denies a user from reading user documents of a different institution', async () => {
      const aliceDb = testEnv.authenticatedContext('alice_mit', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(aliceDb.collection('users').doc('charlie_stanford').get());
    });

    it('denies unauthenticated requests from reading user documents', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      await assertFails(unauthDb.collection('users').doc('alice_mit').get());
    });

    it('allows a user to read clubs in their own institution', async () => {
      const aliceDb = testEnv.authenticatedContext('alice_mit', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(aliceDb.collection('clubs').doc('club_mit_robotics').get());
    });

    it('denies a user from reading clubs in a different institution', async () => {
      const aliceDb = testEnv.authenticatedContext('alice_mit', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(aliceDb.collection('clubs').doc('club_stanford_ai').get());
    });

    it('allows a user to read events in their own institution', async () => {
      const aliceDb = testEnv.authenticatedContext('alice_mit', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(aliceDb.collection('events').doc('evt_mit_hackathon').get());
    });

    it('denies a user from reading events in a different institution', async () => {
      const aliceDb = testEnv.authenticatedContext('alice_mit', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(aliceDb.collection('events').doc('evt_stanford_summit').get());
    });

    it('allows a user to read audit logs within their institution', async () => {
      const aliceDb = testEnv.authenticatedContext('alice_mit', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(aliceDb.collection('audit_logs').doc('log_mit_1').get());
    });

    it('denies a user from reading audit logs of another institution', async () => {
      const aliceDb = testEnv.authenticatedContext('alice_mit', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(aliceDb.collection('audit_logs').doc('log_stanford_1').get());
    });
  });

  // =========================================================================
  // 2. Role Escalation & Privilege Lockdown Tests
  // =========================================================================
  describe('2. Role Escalation & Privilege Lockdown', () => {
    beforeEach(async () => {
      await seedUser({
        uid: 'student_attacker',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'student',
        first_name: 'Attacker',
        last_name: 'User',
        is_president_of: [],
        is_organizer_of: [],
        clubs_joined: [],
        clubs_created: [],
        account_status: 'active',
      });
    });

    it('denies a student from directly modifying is_president_of array', async () => {
      const studentDb = testEnv.authenticatedContext('student_attacker', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        studentDb.collection('users').doc('student_attacker').update({
          is_president_of: ['club_cs_society'],
        })
      );
    });

    it('denies a student from directly modifying is_organizer_of array', async () => {
      const studentDb = testEnv.authenticatedContext('student_attacker', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        studentDb.collection('users').doc('student_attacker').update({
          is_organizer_of: ['club_cs_society'],
        })
      );
    });

    it('denies a student from directly modifying clubs_joined array', async () => {
      const studentDb = testEnv.authenticatedContext('student_attacker', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        studentDb.collection('users').doc('student_attacker').update({
          clubs_joined: ['club_cs_society'],
        })
      );
    });

    it('denies a student from directly modifying clubs_created array', async () => {
      const studentDb = testEnv.authenticatedContext('student_attacker', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        studentDb.collection('users').doc('student_attacker').update({
          clubs_created: ['club_cs_society'],
        })
      );
    });

    it('denies a student from self-elevating user_type to faculty or admin', async () => {
      const studentDb = testEnv.authenticatedContext('student_attacker', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        studentDb.collection('users').doc('student_attacker').update({
          user_type: 'faculty',
        })
      );

      await assertFails(
        studentDb.collection('users').doc('student_attacker').update({
          user_type: 'admin',
        })
      );
    });

    it('denies a user from changing their institution_id (tenant hopping)', async () => {
      const studentDb = testEnv.authenticatedContext('student_attacker', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        studentDb.collection('users').doc('student_attacker').update({
          institution_id: 'inst_stanford',
        })
      );
    });

    it('denies a user from modifying account_status directly', async () => {
      const studentDb = testEnv.authenticatedContext('student_attacker', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        studentDb.collection('users').doc('student_attacker').update({
          account_status: 'verified_vip',
        })
      );
    });

    it('allows a user to update all 15 safe profile fields', async () => {
      const studentDb = testEnv.authenticatedContext('student_attacker', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(
        studentDb.collection('users').doc('student_attacker').update({
          first_name: 'Alex',
          last_name: 'Smith',
          full_name: 'Alex Smith',
          full_name_lower: 'alex smith',
          search_keywords: ['alex', 'smith'],
          about: 'Undergraduate Researcher in Robotics',
          phone_number: '+16175551234',
          profile_image_url: 'https://cdn.example.com/avatar.png',
          fcm_token: 'fcm_sample_token_xyz',
          last_token_updated_at: '2026-08-30T12:00:00Z',
          last_login_at: '2026-08-30T12:00:00Z',
          is_online: true,
          last_active_at: '2026-08-30T12:00:00Z',
          profile_completed: true,
          updated_at: '2026-08-30T12:00:00Z',
        })
      );
    });
  });

  // =========================================================================
  // 3. Cross-User Role Tampering & Lateral Denial Tests
  // =========================================================================
  describe('3. Cross-User Role Tampering Denial', () => {
    beforeEach(async () => {
      await seedUser({
        uid: 'student_alice',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'student',
        first_name: 'Alice',
      });
      await seedUser({
        uid: 'student_bob',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'student',
        first_name: 'Bob',
        is_president_of: ['club_robotics'],
      });
    });

    it('denies a peer in the same institution from updating another user profile', async () => {
      const aliceDb = testEnv.authenticatedContext('student_alice', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        aliceDb.collection('users').doc('student_bob').update({
          about: 'Unauthorized profile rewrite',
        })
      );
    });

    it('denies a peer in the same institution from modifying another user role arrays', async () => {
      const aliceDb = testEnv.authenticatedContext('student_alice', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        aliceDb.collection('users').doc('student_bob').update({
          is_president_of: [],
        })
      );
    });

    it('denies a peer from writing to another user device subcollection', async () => {
      const aliceDb = testEnv.authenticatedContext('student_alice', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        aliceDb
          .collection('users')
          .doc('student_bob')
          .collection('devices')
          .doc('dev_bob_phone')
          .set({
            fcm_token: 'malicious_token',
          })
      );
    });
  });

  // =========================================================================
  // 4. Faculty Account Status Gating on Club Creation Tests
  // =========================================================================
  describe('4. Faculty Account Status Gating on Club Creation', () => {
    beforeEach(async () => {
      // Active verified faculty
      await seedUser({
        uid: 'faculty_active_1',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'faculty',
        account_status: 'active',
      });

      // Legacy faculty (no account_status field)
      await seedUser({
        uid: 'faculty_legacy_1',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'faculty',
      });

      // Unverified faculty (pending verification)
      await seedUser({
        uid: 'faculty_pending_1',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'faculty',
        account_status: 'pending_verification',
      });

      // Suspended faculty
      await seedUser({
        uid: 'faculty_suspended_1',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'faculty',
        account_status: 'suspended',
      });

      // Regular student
      await seedUser({
        uid: 'student_active_1',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'student',
        account_status: 'active',
      });
    });

    it('allows an active verified faculty member to create a club in their institution', async () => {
      const facultyDb = testEnv.authenticatedContext('faculty_active_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(
        facultyDb.collection('clubs').doc('club_quantum_computing').set({
          club_id: 'club_quantum_computing',
          name: 'Quantum Computing Club',
          club_master_id: 'faculty_active_1',
          institution_id: 'inst_mit',
          college_name: 'MIT',
        })
      );
    });

    it('allows legacy faculty without explicit account_status field to create a club', async () => {
      const facultyDb = testEnv.authenticatedContext('faculty_legacy_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(
        facultyDb.collection('clubs').doc('club_optics').set({
          club_id: 'club_optics',
          name: 'Optics Club',
          club_master_id: 'faculty_legacy_1',
          institution_id: 'inst_mit',
          college_name: 'MIT',
        })
      );
    });

    it('denies a pending_verification faculty member from creating a club', async () => {
      const pendingDb = testEnv.authenticatedContext('faculty_pending_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        pendingDb.collection('clubs').doc('club_cyber_sec').set({
          club_id: 'club_cyber_sec',
          name: 'Cyber Security Club',
          club_master_id: 'faculty_pending_1',
          institution_id: 'inst_mit',
          college_name: 'MIT',
        })
      );
    });

    it('denies a suspended faculty member from creating a club', async () => {
      const suspendedDb = testEnv.authenticatedContext('faculty_suspended_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        suspendedDb.collection('clubs').doc('club_nanotech').set({
          club_id: 'club_nanotech',
          name: 'Nanotech Club',
          club_master_id: 'faculty_suspended_1',
          institution_id: 'inst_mit',
          college_name: 'MIT',
        })
      );
    });

    it('denies a student from creating a club regardless of account_status', async () => {
      const studentDb = testEnv.authenticatedContext('student_active_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        studentDb.collection('clubs').doc('club_gaming').set({
          club_id: 'club_gaming',
          name: 'Gaming Club',
          club_master_id: 'student_active_1',
          institution_id: 'inst_mit',
          college_name: 'MIT',
        })
      );
    });

    it('denies faculty from creating a club in a different institution', async () => {
      const facultyDb = testEnv.authenticatedContext('faculty_active_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        facultyDb.collection('clubs').doc('club_stanford_branch').set({
          club_id: 'club_stanford_branch',
          name: 'Stanford Branch',
          club_master_id: 'faculty_active_1',
          institution_id: 'inst_stanford',
          college_name: 'Stanford',
        })
      );
    });

    it('denies faculty from assigning another user as club_master_id on creation', async () => {
      const facultyDb = testEnv.authenticatedContext('faculty_active_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        facultyDb.collection('clubs').doc('club_spoofed_master').set({
          club_id: 'club_spoofed_master',
          name: 'Spoofed Master Club',
          club_master_id: 'faculty_pending_1',
          institution_id: 'inst_mit',
          college_name: 'MIT',
        })
      );
    });
  });

  // =========================================================================
  // 5. Audit Log Immutability & Actor Verification Tests
  // =========================================================================
  describe('5. Audit Log Immutability & Actor Verification', () => {
    beforeEach(async () => {
      await seedUser({
        uid: 'user_actor_1',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'student',
      });
      await seedUser({
        uid: 'user_target_1',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'faculty',
      });
      await seedAuditLog({
        audit_log_id: 'log_immutable_1',
        institution_id: 'inst_mit',
        actor_user_id: 'user_actor_1',
        action: 'club_joined',
        created_at: '2026-08-30T10:00:00Z',
      });
    });

    it('allows a user to create an audit log with their own UID and institution', async () => {
      const actorDb = testEnv.authenticatedContext('user_actor_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(
        actorDb.collection('audit_logs').doc('log_new_valid').set({
          audit_log_id: 'log_new_valid',
          institution_id: 'inst_mit',
          actor_user_id: 'user_actor_1',
          action: 'event_rsvp',
          created_at: '2026-08-30T10:05:00Z',
        })
      );
    });

    it('denies audit log creation when actor_user_id is spoofed', async () => {
      const actorDb = testEnv.authenticatedContext('user_actor_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        actorDb.collection('audit_logs').doc('log_spoofed_actor').set({
          audit_log_id: 'log_spoofed_actor',
          institution_id: 'inst_mit',
          actor_user_id: 'user_target_1', // Mismatched actor
          action: 'disciplinary_action',
        })
      );
    });

    it('denies audit log creation when institution_id does not match caller', async () => {
      const actorDb = testEnv.authenticatedContext('user_actor_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        actorDb.collection('audit_logs').doc('log_spoofed_inst').set({
          audit_log_id: 'log_spoofed_inst',
          institution_id: 'inst_stanford', // Cross-tenant spoofing
          actor_user_id: 'user_actor_1',
          action: 'event_rsvp',
        })
      );
    });

    it('categorically denies any update to an existing audit log', async () => {
      const actorDb = testEnv.authenticatedContext('user_actor_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        actorDb.collection('audit_logs').doc('log_immutable_1').update({
          action: 'tampered_action',
        })
      );
    });

    it('categorically denies any deletion of an existing audit log', async () => {
      const actorDb = testEnv.authenticatedContext('user_actor_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(actorDb.collection('audit_logs').doc('log_immutable_1').delete());
    });
  });

  // =========================================================================
  // 6. Club Subcollection Memberships Tests
  // =========================================================================
  describe('6. Club Memberships Subcollection', () => {
    beforeEach(async () => {
      await seedUser({
        uid: 'faculty_master',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'faculty',
        account_status: 'active',
      });
      await seedUser({
        uid: 'student_pres',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'student',
        account_status: 'active',
      });
      await seedUser({
        uid: 'student_member',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'student',
        account_status: 'active',
      });
      await seedClub({
        club_id: 'club_robotics',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        club_master_id: 'faculty_master',
        president_id: 'student_pres',
        organizers: [],
      });
    });

    it('allows a student to self-join a club within their institution', async () => {
      const memberDb = testEnv.authenticatedContext('student_member', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(
        memberDb
          .collection('clubs')
          .doc('club_robotics')
          .collection('memberships')
          .doc('student_member')
          .set({
            user_id: 'student_member',
            club_id: 'club_robotics',
            institution_id: 'inst_mit',
            role: 'member',
            status: 'active',
          })
      );
    });

    it('allows a member to self-leave a club', async () => {
      // Seed existing membership
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context
          .firestore()
          .collection('clubs')
          .doc('club_robotics')
          .collection('memberships')
          .doc('student_member')
          .set({
            user_id: 'student_member',
            club_id: 'club_robotics',
            institution_id: 'inst_mit',
            role: 'member',
            status: 'active',
          });
      });

      const memberDb = testEnv.authenticatedContext('student_member', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(
        memberDb
          .collection('clubs')
          .doc('club_robotics')
          .collection('memberships')
          .doc('student_member')
          .update({
            status: 'left',
            role: 'member',
            updated_at: '2026-08-30T12:00:00Z',
          })
      );
    });

    it('denies a member from self-promoting to president or organizer', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context
          .firestore()
          .collection('clubs')
          .doc('club_robotics')
          .collection('memberships')
          .doc('student_member')
          .set({
            user_id: 'student_member',
            club_id: 'club_robotics',
            institution_id: 'inst_mit',
            role: 'member',
            status: 'active',
          });
      });

      const memberDb = testEnv.authenticatedContext('student_member', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        memberDb
          .collection('clubs')
          .doc('club_robotics')
          .collection('memberships')
          .doc('student_member')
          .update({
            role: 'president',
          })
      );
    });

    it('allows club president to update a membership role', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context
          .firestore()
          .collection('clubs')
          .doc('club_robotics')
          .collection('memberships')
          .doc('student_member')
          .set({
            user_id: 'student_member',
            club_id: 'club_robotics',
            institution_id: 'inst_mit',
            role: 'member',
            status: 'active',
          });
      });

      const presDb = testEnv.authenticatedContext('student_pres', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(
        presDb
          .collection('clubs')
          .doc('club_robotics')
          .collection('memberships')
          .doc('student_member')
          .update({
            role: 'organizer',
            status: 'active',
          })
      );
    });

    it('denies membership deletion', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context
          .firestore()
          .collection('clubs')
          .doc('club_robotics')
          .collection('memberships')
          .doc('student_member')
          .set({
            user_id: 'student_member',
            club_id: 'club_robotics',
            institution_id: 'inst_mit',
            role: 'member',
            status: 'active',
          });
      });

      const memberDb = testEnv.authenticatedContext('student_member', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        memberDb
          .collection('clubs')
          .doc('club_robotics')
          .collection('memberships')
          .doc('student_member')
          .delete()
      );
    });
  });

  // =========================================================================
  // 7. Event Management & Status Permission Tests
  // =========================================================================
  describe('7. Event Management & Status Permissions', () => {
    beforeEach(async () => {
      await seedUser({
        uid: 'faculty_master_1',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'faculty',
      });
      await seedUser({
        uid: 'student_pres_1',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'student',
      });
      await seedUser({
        uid: 'student_org_1',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'student',
      });
      await seedUser({
        uid: 'student_regular_1',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'student',
      });
      await seedClub({
        club_id: 'club_cs',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        club_master_id: 'faculty_master_1',
        president_id: 'student_pres_1',
        organizers: ['student_org_1'],
      });
      await seedEvent({
        event_id: 'evt_tech_talk',
        club_id: 'club_cs',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        created_by_id: 'student_pres_1',
        status: 'draft',
        current_participants: 0,
        interested_count: 0,
        not_going_count: 0,
      });
    });

    it('allows club master to approve and change event status', async () => {
      const masterDb = testEnv.authenticatedContext('faculty_master_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(
        masterDb.collection('events').doc('evt_tech_talk').update({
          status: 'approved',
        })
      );
    });

    it('denies organizer from changing event status', async () => {
      const orgDb = testEnv.authenticatedContext('student_org_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        orgDb.collection('events').doc('evt_tech_talk').update({
          status: 'approved',
        })
      );
    });

    it('allows any student in same tenant to update RSVP counts via isRsvpCountUpdate', async () => {
      const regularDb = testEnv.authenticatedContext('student_regular_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(
        regularDb.collection('events').doc('evt_tech_talk').update({
          current_participants: 1,
          interested_count: 5,
          not_going_count: 0,
          updated_at: '2026-08-30T12:00:00Z',
        })
      );
    });
  });

  // =========================================================================
  // 8. RSVP Enum Validation & User Scoping Tests
  // =========================================================================
  describe('8. RSVP Enum Validation & User Scoping', () => {
    beforeEach(async () => {
      await seedUser({
        uid: 'student_rsvp_1',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'student',
      });
      await seedClub({
        club_id: 'club_cs',
        institution_id: 'inst_mit',
        college_name: 'MIT',
      });
      await seedEvent({
        event_id: 'evt_hackathon',
        club_id: 'club_cs',
        institution_id: 'inst_mit',
        college_name: 'MIT',
      });
    });

    it('allows valid RSVP response enums (attending, interested, not_going)', async () => {
      const studentDb = testEnv.authenticatedContext('student_rsvp_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(
        studentDb
          .collection('events')
          .doc('evt_hackathon')
          .collection('rsvps')
          .doc('student_rsvp_1')
          .set({
            user_id: 'student_rsvp_1',
            response: 'attending',
          })
      );

      await assertSucceeds(
        studentDb
          .collection('events')
          .doc('evt_hackathon')
          .collection('rsvps')
          .doc('student_rsvp_1')
          .set({
            user_id: 'student_rsvp_1',
            response: 'interested',
          })
      );

      await assertSucceeds(
        studentDb
          .collection('events')
          .doc('evt_hackathon')
          .collection('rsvps')
          .doc('student_rsvp_1')
          .set({
            user_id: 'student_rsvp_1',
            response: 'not_going',
          })
      );
    });

    it('denies invalid RSVP response string', async () => {
      const studentDb = testEnv.authenticatedContext('student_rsvp_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        studentDb
          .collection('events')
          .doc('evt_hackathon')
          .collection('rsvps')
          .doc('student_rsvp_1')
          .set({
            user_id: 'student_rsvp_1',
            response: 'super_excited',
          })
      );
    });

    it('denies RSVPing on behalf of another user', async () => {
      const studentDb = testEnv.authenticatedContext('student_rsvp_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        studentDb
          .collection('events')
          .doc('evt_hackathon')
          .collection('rsvps')
          .doc('student_other')
          .set({
            user_id: 'student_other',
            response: 'attending',
          })
      );
    });
  });

  // =========================================================================
  // 9. Storage Assets Access Control Tests
  // =========================================================================
  describe('9. Storage Assets Access Control', () => {
    beforeEach(async () => {
      await seedUser({
        uid: 'user_uploader_1',
        institution_id: 'inst_mit',
        college_name: 'MIT',
        user_type: 'student',
      });
      await seedStorageAsset({
        asset_id: 'asset_existing_1',
        institution_id: 'inst_mit',
        owner_id: 'user_uploader_1',
        storage_path: 'profiles/user_uploader_1/avatar.png',
        content_type: 'image/png',
        size: 2048,
      });
    });

    it('allows a user to register an image storage asset owned by them', async () => {
      const uploaderDb = testEnv.authenticatedContext('user_uploader_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertSucceeds(
        uploaderDb.collection('storage_assets').doc('asset_new_img').set({
          asset_id: 'asset_new_img',
          owner_id: 'user_uploader_1',
          institution_id: 'inst_mit',
          storage_path: 'banners/club_banner.jpg',
          content_type: 'image/jpeg',
          size: 10240,
        })
      );
    });

    it('denies registration of non-image storage assets', async () => {
      const uploaderDb = testEnv.authenticatedContext('user_uploader_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        uploaderDb.collection('storage_assets').doc('asset_bad_mime').set({
          asset_id: 'asset_bad_mime',
          owner_id: 'user_uploader_1',
          institution_id: 'inst_mit',
          storage_path: 'executables/payload.exe',
          content_type: 'application/octet-stream',
          size: 1024,
        })
      );
    });

    it('denies storage asset deletion', async () => {
      const uploaderDb = testEnv.authenticatedContext('user_uploader_1', {
        institution_id: 'inst_mit',
      }).firestore();

      await assertFails(
        uploaderDb.collection('storage_assets').doc('asset_existing_1').delete()
      );
    });
  });
});
