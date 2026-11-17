-- NERRA Application SQL Queries
-- Team: T0123 | Project: NERRA | CP3
-- These are illustrative application queries. Replace UUID literals with
-- IDs from the benchmark fixture before execution.

-- Q1: Fetch user by email for authentication
-- READ
SELECT id, email, password_hash, display_name, created_at
FROM users
WHERE email = 'author@nerra.ai';

-- Q2: Create a project
-- WRITE
INSERT INTO projects (id, owner_id, title, genre, created_at)
VALUES (uuid_generate_v4(), '00000000-0000-0000-0000-000000000001',
        'Chronicles of Solaria', 'Fantasy', NOW())
RETURNING id, title, created_at;

-- Q3: Project dashboard with manuscript and open-issue counts
-- READ
SELECT p.id, p.title, p.genre, p.created_at,
       COUNT(DISTINCT m.id) AS total_manuscripts,
       COUNT(DISTINCT i.id) FILTER (WHERE i.status = 'open') AS open_issues_count
FROM projects AS p
LEFT JOIN manuscripts AS m ON m.project_id = p.id
LEFT JOIN issues AS i ON i.project_id = p.id
WHERE p.owner_id = '00000000-0000-0000-0000-000000000001'
GROUP BY p.id
ORDER BY p.created_at DESC;

-- Q4: Ingest a manuscript draft
-- WRITE
INSERT INTO manuscripts (id, project_id, title, raw_text, status,
                         chapters_done, chapters_total, created_at)
VALUES (uuid_generate_v4(), '00000000-0000-0000-0000-000000000002',
        'Manuscript Draft 1', 'Chapter 1: The Gathering...',
        'processing', 0, 10, NOW())
RETURNING id, status;

-- Q5: Update manuscript ingestion progress
-- WRITE
UPDATE manuscripts
SET chapters_done = 5, status = 'processing'
WHERE id = '00000000-0000-0000-0000-000000000003';

-- Q6: Project characters with relationship counts
-- READ
SELECT c.id, c.name, c.status, c.description, c.first_chapter, c.last_chapter,
       COUNT(r.id) AS relationship_count
FROM characters AS c
LEFT JOIN relationships AS r
  ON r.character_a_id = c.id OR r.character_b_id = c.id
WHERE c.project_id = '00000000-0000-0000-0000-000000000002'
GROUP BY c.id
ORDER BY c.name;

-- Q7: Register an extracted character
-- WRITE
INSERT INTO characters
(id, project_id, name, aliases, description, status, physical_traits,
 first_chapter, last_chapter, created_at)
VALUES
(uuid_generate_v4(), '00000000-0000-0000-0000-000000000002',
 'Lord Kaelen', '["The Shadow Duke", "Kael"]'::jsonb,
 'High inquisitor of the eastern realm.', 'alive',
 '{"hair":"silver","eyes":"violet"}'::jsonb, 1, 1, NOW())
RETURNING id;

-- Q8: Relationship lookup between two characters (either direction)
-- READ
SELECT r.id, c1.name AS character_a, c2.name AS character_b,
       r.type AS relationship_type, r.sentiment, r.evidence_quote,
       r.chapter, r.until_chapter
FROM relationships AS r
JOIN characters AS c1 ON c1.id = r.character_a_id
JOIN characters AS c2 ON c2.id = r.character_b_id
WHERE r.project_id = '00000000-0000-0000-0000-000000000002'
  AND ((r.character_a_id = '00000000-0000-0000-0000-000000000004'
        AND r.character_b_id = '00000000-0000-0000-0000-000000000005')
    OR (r.character_a_id = '00000000-0000-0000-0000-000000000005'
        AND r.character_b_id = '00000000-0000-0000-0000-000000000004'));

-- Q9: Record a relationship
-- WRITE
INSERT INTO relationships
(id, project_id, character_a_id, character_b_id, type, sentiment,
 description, evidence_quote, chapter, created_at)
VALUES
(uuid_generate_v4(), '00000000-0000-0000-0000-000000000002',
 '00000000-0000-0000-0000-000000000004',
 '00000000-0000-0000-0000-000000000005',
 'rival', 'hostile', 'Clashing over control of the ancient citadel.',
 'Their blades met before either spoke a word.', 3, NOW());

-- Q10: Chronological timeline events
-- READ
SELECT e.id, e.chapter_number, e.scene_order, e.story_time_order,
       e.temporal_anchor, e.is_flashback, e.is_flashforward,
       e.summary, e.participants, e.location
FROM events AS e
WHERE e.project_id = '00000000-0000-0000-0000-000000000002'
ORDER BY e.story_time_order, e.chapter_number, e.scene_order;

-- Q11: Add a timeline event
-- WRITE
INSERT INTO events
(id, project_id, chapter_number, scene_order, story_time_order,
 temporal_anchor, is_flashback, is_flashforward, summary, participants,
 location, created_at)
VALUES
(uuid_generate_v4(), '00000000-0000-0000-0000-000000000002',
 4, 1, 12, 'Midnight during the eclipse', FALSE, FALSE,
 'The duel atop the watchtower commences.',
 '["Lord Kaelen", "Sarah"]'::jsonb, 'Watchtower of Solaria', NOW());

-- Q12: Detect possible attribute contradictions between active claims
-- READ
SELECT c1.id AS claim_a_id, c1.subject, c1.attribute,
       c1.value AS value_a, c1.chapter AS chapter_a,
       c1.evidence_quote AS evidence_a,
       c2.id AS claim_b_id, c2.value AS value_b,
       c2.chapter AS chapter_b, c2.evidence_quote AS evidence_b
FROM claims AS c1
JOIN claims AS c2
  ON c1.project_id = c2.project_id
 AND LOWER(c1.subject) = LOWER(c2.subject)
 AND LOWER(c1.attribute) = LOWER(c2.attribute)
 AND c1.id < c2.id
 AND LOWER(c1.value) <> LOWER(c2.value)
WHERE c1.project_id = '00000000-0000-0000-0000-000000000002'
  AND c1.status = 'active'
  AND c2.status = 'active';

-- Q13: Insert a factual claim
-- WRITE
INSERT INTO claims
(id, project_id, subject, attribute, value, chapter, evidence_quote,
 source_paragraph_id, confidence, validation_state, status, created_at)
VALUES
(uuid_generate_v4(), '00000000-0000-0000-0000-000000000002',
 'Sarah', 'eye_color', 'amber', 8,
 'Her amber eyes narrowed against the smoke.', 'p-8-22',
 0.98, 'AUTO_ACCEPTED', 'active', NOW());

-- Q14: Open issues joined with their originating claims
-- READ
SELECT i.id, i.type, i.severity, i.status, i.description, i.confidence,
       i.ai_reasoning, ca.subject AS claim_a_subject,
       ca.value AS claim_a_value, ca.chapter AS claim_a_chapter,
       cb.value AS claim_b_value, cb.chapter AS claim_b_chapter
FROM issues AS i
LEFT JOIN claims AS ca ON ca.id = i.claim_a_id
LEFT JOIN claims AS cb ON cb.id = i.claim_b_id
WHERE i.project_id = '00000000-0000-0000-0000-000000000002'
  AND i.status = 'open'
ORDER BY CASE i.severity WHEN 'red' THEN 1 WHEN 'yellow' THEN 2 ELSE 3 END,
         i.created_at DESC;

-- Q15: Log a consistency issue
-- WRITE
INSERT INTO issues
(id, project_id, type, severity, status, description, confidence,
 ai_reasoning, claim_a_id, claim_b_id, created_at)
VALUES
(uuid_generate_v4(), '00000000-0000-0000-0000-000000000002',
 'attribute_contradiction', 'red', 'open',
 'Sarah eye_color contradicts an earlier mention.', 0.95,
 'Chapter 1 mentions green eyes while Chapter 8 mentions amber eyes.',
 '00000000-0000-0000-0000-000000000006',
 '00000000-0000-0000-0000-000000000007', NOW());

-- Q16: Resolve an issue
-- WRITE
UPDATE issues
SET status = 'resolved',
    ai_reasoning = 'Author confirmed intentional shape-shifting trait.'
WHERE id = '00000000-0000-0000-0000-000000000008';

-- Q17: Trace object custody across chapters
-- READ
SELECT o.id AS object_id, o.name AS object_name,
       oce.chapter, oce.holder_type, oce.holder_name,
       oce.action, oce.evidence_quote, oce.created_at
FROM objects AS o
JOIN object_custody_events AS oce ON oce.object_id = o.id
WHERE o.project_id = '00000000-0000-0000-0000-000000000002'
ORDER BY o.name, oce.chapter, oce.created_at;

-- Q18: Track a character's knowledge state
-- READ
SELECT ku.id, ku.character, ku.fact, ku.chapter,
       ku.how_learned, ku.source_character
FROM knowledge_updates AS ku
WHERE ku.project_id = '00000000-0000-0000-0000-000000000002'
  AND ku.character = 'John'
ORDER BY ku.chapter;

-- Q19: Fetch unresolved plot threads
-- READ
SELECT pt.id, pt.title, pt.description, pt.setup_chapter,
       pt.payoff_chapter, pt.status, pt.evidence_quote
FROM plot_threads AS pt
WHERE pt.project_id = '00000000-0000-0000-0000-000000000002'
  AND pt.status IN ('open', 'abandoned')
ORDER BY pt.setup_chapter;

-- Q20: Resolve a plot thread
-- WRITE
UPDATE plot_threads
SET status = 'resolved', payoff_chapter = 12, updated_at = NOW()
WHERE id = '00000000-0000-0000-0000-000000000009';
