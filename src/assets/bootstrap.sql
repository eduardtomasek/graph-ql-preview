-- Idempotent bootstrap SQL for a test card-game API
-- Stack target: NestJS + PostgreSQL projections + Redis + GraphQL
-- Safe to run repeatedly.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS card_types (
  id smallserial PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL
);

CREATE TABLE IF NOT EXISTS factions (
  id smallserial PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  alignment text,
  description text
);

CREATE TABLE IF NOT EXISTS rarities (
  id smallserial PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  sort_order int NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS card_sets (
  id smallserial PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  release_order int NOT NULL UNIQUE,
  is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS cards (
  id bigserial PRIMARY KEY,
  uuid uuid NOT NULL DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  card_type_id smallint NOT NULL REFERENCES card_types(id),
  faction_id smallint NOT NULL REFERENCES factions(id),
  rarity_id smallint NOT NULL REFERENCES rarities(id),
  set_id smallint NOT NULL REFERENCES card_sets(id),
  cost int NOT NULL CHECK (cost >= 0),
  lore_text text,
  rules_text text,
  image_url text,
  is_collectible boolean NOT NULL DEFAULT true,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS card_combat_stats (
  card_id bigint PRIMARY KEY REFERENCES cards(id) ON DELETE CASCADE,
  attack int NOT NULL CHECK (attack >= 0),
  defense int NOT NULL CHECK (defense >= 0),
  health int NOT NULL CHECK (health >= 1),
  speed int NOT NULL CHECK (speed >= 0),
  range int NOT NULL CHECK (range >= 0),
  armor int NOT NULL CHECK (armor >= 0)
);

CREATE TABLE IF NOT EXISTS ability_trigger_types (
  id smallserial PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL
);

CREATE TABLE IF NOT EXISTS ability_effect_types (
  id smallserial PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL
);

CREATE TABLE IF NOT EXISTS abilities (
  id smallserial PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text NOT NULL,
  trigger_type_id smallint NOT NULL REFERENCES ability_trigger_types(id),
  effect_type_id smallint NOT NULL REFERENCES ability_effect_types(id)
);

CREATE TABLE IF NOT EXISTS card_abilities (
  card_id bigint NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  ability_id smallint NOT NULL REFERENCES abilities(id),
  sort_order int NOT NULL DEFAULT 0,
  PRIMARY KEY (card_id, ability_id)
);

CREATE TABLE IF NOT EXISTS tags (
  id smallserial PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL
);

CREATE TABLE IF NOT EXISTS card_tags (
  card_id bigint NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  tag_id smallint NOT NULL REFERENCES tags(id),
  PRIMARY KEY (card_id, tag_id)
);

CREATE TABLE IF NOT EXISTS card_balance_versions (
  id bigserial PRIMARY KEY,
  card_id bigint NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
  version int NOT NULL,
  cost int NOT NULL,
  attack int,
  defense int,
  health int,
  valid_from timestamptz NOT NULL DEFAULT now(),
  valid_to timestamptz,
  change_note text,
  UNIQUE (card_id, version)
);

CREATE TABLE IF NOT EXISTS projection_cards (
  card_uuid uuid PRIMARY KEY,
  card_code text NOT NULL UNIQUE,
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  type_code text NOT NULL,
  type_name text NOT NULL,
  faction_code text NOT NULL,
  faction_name text NOT NULL,
  rarity_code text NOT NULL,
  rarity_name text NOT NULL,
  set_code text NOT NULL,
  set_name text NOT NULL,
  cost int NOT NULL,
  attack int,
  defense int,
  health int,
  speed int,
  range int,
  armor int,
  tags jsonb NOT NULL DEFAULT '[]'::jsonb,
  abilities jsonb NOT NULL DEFAULT '[]'::jsonb,
  searchable_text text NOT NULL,
  power_score numeric(8,2),
  is_collectible boolean NOT NULL,
  is_active boolean NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS projection_card_lists (
  card_uuid uuid PRIMARY KEY,
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  type_code text NOT NULL,
  faction_code text NOT NULL,
  rarity_code text NOT NULL,
  set_code text NOT NULL,
  cost int NOT NULL,
  attack int,
  defense int,
  health int,
  power_score numeric(8,2),
  tags text[] NOT NULL DEFAULT '{}',
  is_active boolean NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_projection_card_lists_filter
  ON projection_card_lists (faction_code, type_code, rarity_code, cost);

CREATE INDEX IF NOT EXISTS idx_projection_card_lists_tags
  ON projection_card_lists USING gin (tags);

CREATE TABLE IF NOT EXISTS projection_faction_card_stats (
  faction_code text PRIMARY KEY,
  faction_name text NOT NULL,
  total_cards int NOT NULL,
  total_units int NOT NULL,
  total_tactics int NOT NULL,
  avg_cost numeric(8,2),
  avg_attack numeric(8,2),
  avg_defense numeric(8,2),
  legendary_count int NOT NULL,
  tag_distribution jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO card_types (code, name) VALUES  ('unit', 'Unit'),
  ('leader', 'Leader'),
  ('wargear', 'Wargear'),
  ('tactic', 'Tactic'),
  ('doctrine', 'Doctrine')
ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name;

INSERT INTO factions (code, name, alignment, description) VALUES  ('adeptus_astartes', 'Adeptus Astartes', 'Imperium', 'Genetically enhanced transhuman warriors in power armor.'),
  ('tyranids', 'Tyranids', 'Hive Mind', 'A devouring alien swarm driven by synaptic will.'),
  ('orks', 'Orks', 'Waaagh!', 'Brutal green-skinned warriors thriving on battle and noise.')
ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, alignment=EXCLUDED.alignment, description=EXCLUDED.description;

INSERT INTO rarities (code, name, sort_order) VALUES  ('common', 'Common', 1),
  ('uncommon', 'Uncommon', 2),
  ('rare', 'Rare', 3),
  ('epic', 'Epic', 4),
  ('legendary', 'Legendary', 5)
ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, sort_order=EXCLUDED.sort_order;

INSERT INTO card_sets (code, name, release_order, is_active) VALUES  ('core_41st_millennium', 'Core 41st Millennium', 1, true)
ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, release_order=EXCLUDED.release_order, is_active=EXCLUDED.is_active;

INSERT INTO ability_trigger_types (code, name) VALUES  ('on_play', 'On Play'),
  ('on_attack', 'On Attack'),
  ('on_death', 'On Death'),
  ('passive', 'Passive'),
  ('start_of_turn', 'Start Of Turn'),
  ('end_of_turn', 'End Of Turn')
ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name;

INSERT INTO ability_effect_types (code, name) VALUES  ('buff_attack', 'Buff Attack'),
  ('buff_defense', 'Buff Defense'),
  ('deal_damage', 'Deal Damage'),
  ('draw_card', 'Draw Card'),
  ('summon_unit', 'Summon Unit'),
  ('heal', 'Heal'),
  ('grant_armor', 'Grant Armor'),
  ('reduce_cost', 'Reduce Cost')
ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name;

INSERT INTO tags (code, name) VALUES  ('infantry', 'Infantry'),
  ('elite', 'Elite'),
  ('vehicle', 'Vehicle'),
  ('monster', 'Monster'),
  ('swarm', 'Swarm'),
  ('psyker', 'Psyker'),
  ('commander', 'Commander'),
  ('machine', 'Machine'),
  ('beast', 'Beast'),
  ('heavy', 'Heavy'),
  ('fast', 'Fast'),
  ('ranged', 'Ranged'),
  ('melee', 'Melee'),
  ('synapse', 'Synapse'),
  ('boyz', 'Boyz'),
  ('nob', 'Nob'),
  ('beast_snagga', 'Beast Snagga'),
  ('terminator', 'Terminator')
ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name;

INSERT INTO abilities (code, name, description, trigger_type_id, effect_type_id) VALUES
  ('bolter_drill', 'Bolter Drill', 'Ranged units with this card gain +1 attack while attacking wounded enemies.', (SELECT id FROM ability_trigger_types WHERE code='passive'), (SELECT id FROM ability_effect_types WHERE code='buff_attack')),
  ('and_they_shall_know_no_fear', 'And They Shall Know No Fear', 'This unit gains +1 defense this turn.', (SELECT id FROM ability_trigger_types WHERE code='on_play'), (SELECT id FROM ability_effect_types WHERE code='buff_defense')),
  ('synaptic_link', 'Synaptic Link', 'Friendly swarm units gain +1 attack while a synapse unit is in play.', (SELECT id FROM ability_trigger_types WHERE code='passive'), (SELECT id FROM ability_effect_types WHERE code='buff_attack')),
  ('shadow_in_the_warp', 'Shadow in the Warp', 'Enemy tactic cards cost 1 more next turn.', (SELECT id FROM ability_trigger_types WHERE code='on_play'), (SELECT id FROM ability_effect_types WHERE code='reduce_cost')),
  ('waaagh', 'Waaagh!', 'All friendly Ork melee units gain +1 attack this turn.', (SELECT id FROM ability_trigger_types WHERE code='start_of_turn'), (SELECT id FROM ability_effect_types WHERE code='buff_attack')),
  ('more_dakka', 'More Dakka', 'Deal 1 extra damage when this unit attacks from range.', (SELECT id FROM ability_trigger_types WHERE code='on_attack'), (SELECT id FROM ability_effect_types WHERE code='deal_damage')),
  ('regeneration', 'Regeneration', 'Restore 1 health to this unit.', (SELECT id FROM ability_trigger_types WHERE code='end_of_turn'), (SELECT id FROM ability_effect_types WHERE code='heal')),
  ('deep_strike', 'Deep Strike', 'Deploy an extra 1-cost infantry token.', (SELECT id FROM ability_trigger_types WHERE code='on_play'), (SELECT id FROM ability_effect_types WHERE code='summon_unit')),
  ('crushing_charge', 'Crushing Charge', 'Deal 1 damage to the enemy backline after attacking.', (SELECT id FROM ability_trigger_types WHERE code='on_attack'), (SELECT id FROM ability_effect_types WHERE code='deal_damage')),
  ('iron_halo', 'Iron Halo', 'This unit has +1 armor.', (SELECT id FROM ability_trigger_types WHERE code='passive'), (SELECT id FROM ability_effect_types WHERE code='grant_armor'))
ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, description=EXCLUDED.description, trigger_type_id=EXCLUDED.trigger_type_id, effect_type_id=EXCLUDED.effect_type_id;

INSERT INTO cards (code, name, slug, card_type_id, faction_id, rarity_id, set_id, cost, lore_text, rules_text, image_url, is_collectible, is_active) VALUES
  ('adeptus_astartes_intercessor_squad', 'Intercessor Squad', 'adeptus-astartes-intercessor-squad', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 2, 'A Intercessor Squad card from the Adeptus Astartes test faction.', 'Test rules for Intercessor Squad; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-intercessor-squad.webp', true, true),
  ('adeptus_astartes_assault_intercessors', 'Assault Intercessors', 'adeptus-astartes-assault-intercessors', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 2, 'A Assault Intercessors card from the Adeptus Astartes test faction.', 'Test rules for Assault Intercessors; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-assault-intercessors.webp', true, true),
  ('adeptus_astartes_primaris_lieutenant', 'Primaris Lieutenant', 'adeptus-astartes-primaris-lieutenant', (SELECT id FROM card_types WHERE code='leader'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 4, 'A Primaris Lieutenant card from the Adeptus Astartes test faction.', 'Test rules for Primaris Lieutenant; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-primaris-lieutenant.webp', true, true),
  ('adeptus_astartes_redemptor_dreadnought', 'Redemptor Dreadnought', 'adeptus-astartes-redemptor-dreadnought', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='epic'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 6, 'A Redemptor Dreadnought card from the Adeptus Astartes test faction.', 'Test rules for Redemptor Dreadnought; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-redemptor-dreadnought.webp', true, true),
  ('adeptus_astartes_terminator_squad', 'Terminator Squad', 'adeptus-astartes-terminator-squad', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Terminator Squad card from the Adeptus Astartes test faction.', 'Test rules for Terminator Squad; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-terminator-squad.webp', true, true),
  ('adeptus_astartes_bladeguard_veterans', 'Bladeguard Veterans', 'adeptus-astartes-bladeguard-veterans', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 4, 'A Bladeguard Veterans card from the Adeptus Astartes test faction.', 'Test rules for Bladeguard Veterans; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-bladeguard-veterans.webp', true, true),
  ('adeptus_astartes_hellblaster_squad', 'Hellblaster Squad', 'adeptus-astartes-hellblaster-squad', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 4, 'A Hellblaster Squad card from the Adeptus Astartes test faction.', 'Test rules for Hellblaster Squad; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-hellblaster-squad.webp', true, true),
  ('adeptus_astartes_inceptor_squad', 'Inceptor Squad', 'adeptus-astartes-inceptor-squad', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Inceptor Squad card from the Adeptus Astartes test faction.', 'Test rules for Inceptor Squad; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-inceptor-squad.webp', true, true),
  ('adeptus_astartes_captain_in_gravis_armor', 'Captain in Gravis Armor', 'adeptus-astartes-captain-in-gravis-armor', (SELECT id FROM card_types WHERE code='leader'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='legendary'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 6, 'A Captain in Gravis Armor card from the Adeptus Astartes test faction.', 'Test rules for Captain in Gravis Armor; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-captain-in-gravis-armor.webp', true, true),
  ('adeptus_astartes_chaplain_orator', 'Chaplain Orator', 'adeptus-astartes-chaplain-orator', (SELECT id FROM card_types WHERE code='leader'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='epic'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 4, 'A Chaplain Orator card from the Adeptus Astartes test faction.', 'Test rules for Chaplain Orator; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-chaplain-orator.webp', true, true),
  ('adeptus_astartes_librarian_epistolary', 'Librarian Epistolary', 'adeptus-astartes-librarian-epistolary', (SELECT id FROM card_types WHERE code='leader'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='epic'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Librarian Epistolary card from the Adeptus Astartes test faction.', 'Test rules for Librarian Epistolary; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-librarian-epistolary.webp', true, true),
  ('adeptus_astartes_aggressor_squad', 'Aggressor Squad', 'adeptus-astartes-aggressor-squad', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 4, 'A Aggressor Squad card from the Adeptus Astartes test faction.', 'Test rules for Aggressor Squad; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-aggressor-squad.webp', true, true),
  ('adeptus_astartes_eradicator_squad', 'Eradicator Squad', 'adeptus-astartes-eradicator-squad', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Eradicator Squad card from the Adeptus Astartes test faction.', 'Test rules for Eradicator Squad; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-eradicator-squad.webp', true, true),
  ('adeptus_astartes_repulsor_executioner', 'Repulsor Executioner', 'adeptus-astartes-repulsor-executioner', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='legendary'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 8, 'A Repulsor Executioner card from the Adeptus Astartes test faction.', 'Test rules for Repulsor Executioner; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-repulsor-executioner.webp', true, true),
  ('adeptus_astartes_impulsor_transport', 'Impulsor Transport', 'adeptus-astartes-impulsor-transport', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Impulsor Transport card from the Adeptus Astartes test faction.', 'Test rules for Impulsor Transport; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-impulsor-transport.webp', true, true),
  ('adeptus_astartes_storm_speeder', 'Storm Speeder', 'adeptus-astartes-storm-speeder', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Storm Speeder card from the Adeptus Astartes test faction.', 'Test rules for Storm Speeder; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-storm-speeder.webp', true, true),
  ('adeptus_astartes_ancient_banner_bearer', 'Ancient Banner Bearer', 'adeptus-astartes-ancient-banner-bearer', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Ancient Banner Bearer card from the Adeptus Astartes test faction.', 'Test rules for Ancient Banner Bearer; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-ancient-banner-bearer.webp', true, true),
  ('adeptus_astartes_auspex_scan', 'Auspex Scan', 'adeptus-astartes-auspex-scan', (SELECT id FROM card_types WHERE code='tactic'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 1, 'A Auspex Scan card from the Adeptus Astartes test faction.', 'Test rules for Auspex Scan; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-auspex-scan.webp', true, true),
  ('adeptus_astartes_orbital_strike', 'Orbital Strike', 'adeptus-astartes-orbital-strike', (SELECT id FROM card_types WHERE code='tactic'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='epic'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Orbital Strike card from the Adeptus Astartes test faction.', 'Test rules for Orbital Strike; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-orbital-strike.webp', true, true),
  ('adeptus_astartes_oath_of_moment', 'Oath of Moment', 'adeptus-astartes-oath-of-moment', (SELECT id FROM card_types WHERE code='doctrine'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Oath of Moment card from the Adeptus Astartes test faction.', 'Test rules for Oath of Moment; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-oath-of-moment.webp', true, true),
  ('adeptus_astartes_purity_seal', 'Purity Seal', 'adeptus-astartes-purity-seal', (SELECT id FROM card_types WHERE code='wargear'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 1, 'A Purity Seal card from the Adeptus Astartes test faction.', 'Test rules for Purity Seal; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-purity-seal.webp', true, true),
  ('adeptus_astartes_relic_blade', 'Relic Blade', 'adeptus-astartes-relic-blade', (SELECT id FROM card_types WHERE code='wargear'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 2, 'A Relic Blade card from the Adeptus Astartes test faction.', 'Test rules for Relic Blade; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-relic-blade.webp', true, true),
  ('adeptus_astartes_storm_shield', 'Storm Shield', 'adeptus-astartes-storm-shield', (SELECT id FROM card_types WHERE code='wargear'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 2, 'A Storm Shield card from the Adeptus Astartes test faction.', 'Test rules for Storm Shield; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-storm-shield.webp', true, true),
  ('adeptus_astartes_drop_pod_assault', 'Drop Pod Assault', 'adeptus-astartes-drop-pod-assault', (SELECT id FROM card_types WHERE code='tactic'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Drop Pod Assault card from the Adeptus Astartes test faction.', 'Test rules for Drop Pod Assault; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-drop-pod-assault.webp', true, true),
  ('adeptus_astartes_codex_discipline', 'Codex Discipline', 'adeptus-astartes-codex-discipline', (SELECT id FROM card_types WHERE code='doctrine'), (SELECT id FROM factions WHERE code='adeptus_astartes'), (SELECT id FROM rarities WHERE code='legendary'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Codex Discipline card from the Adeptus Astartes test faction.', 'Test rules for Codex Discipline; generated for read-model and cache experiments.', 'https://example.test/cards/adeptus-astartes-codex-discipline.webp', true, true),
  ('tyranids_termagant_brood', 'Termagant Brood', 'tyranids-termagant-brood', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 1, 'A Termagant Brood card from the Tyranids test faction.', 'Test rules for Termagant Brood; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-termagant-brood.webp', true, true),
  ('tyranids_hormagaunt_swarm', 'Hormagaunt Swarm', 'tyranids-hormagaunt-swarm', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 1, 'A Hormagaunt Swarm card from the Tyranids test faction.', 'Test rules for Hormagaunt Swarm; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-hormagaunt-swarm.webp', true, true),
  ('tyranids_warrior_brood', 'Warrior Brood', 'tyranids-warrior-brood', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Warrior Brood card from the Tyranids test faction.', 'Test rules for Warrior Brood; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-warrior-brood.webp', true, true),
  ('tyranids_hive_tyrant', 'Hive Tyrant', 'tyranids-hive-tyrant', (SELECT id FROM card_types WHERE code='leader'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='legendary'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 7, 'A Hive Tyrant card from the Tyranids test faction.', 'Test rules for Hive Tyrant; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-hive-tyrant.webp', true, true),
  ('tyranids_carnifex', 'Carnifex', 'tyranids-carnifex', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Carnifex card from the Tyranids test faction.', 'Test rules for Carnifex; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-carnifex.webp', true, true),
  ('tyranids_tyrannofex', 'Tyrannofex', 'tyranids-tyrannofex', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='epic'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 7, 'A Tyrannofex card from the Tyranids test faction.', 'Test rules for Tyrannofex; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-tyrannofex.webp', true, true),
  ('tyranids_zoanthrope_node', 'Zoanthrope Node', 'tyranids-zoanthrope-node', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 4, 'A Zoanthrope Node card from the Tyranids test faction.', 'Test rules for Zoanthrope Node; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-zoanthrope-node.webp', true, true),
  ('tyranids_genestealer_pack', 'Genestealer Pack', 'tyranids-genestealer-pack', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Genestealer Pack card from the Tyranids test faction.', 'Test rules for Genestealer Pack; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-genestealer-pack.webp', true, true),
  ('tyranids_lictor_ambusher', 'Lictor Ambusher', 'tyranids-lictor-ambusher', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 4, 'A Lictor Ambusher card from the Tyranids test faction.', 'Test rules for Lictor Ambusher; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-lictor-ambusher.webp', true, true),
  ('tyranids_neurotyrant', 'Neurotyrant', 'tyranids-neurotyrant', (SELECT id FROM card_types WHERE code='leader'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='epic'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Neurotyrant card from the Tyranids test faction.', 'Test rules for Neurotyrant; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-neurotyrant.webp', true, true),
  ('tyranids_ripper_swarm', 'Ripper Swarm', 'tyranids-ripper-swarm', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 1, 'A Ripper Swarm card from the Tyranids test faction.', 'Test rules for Ripper Swarm; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-ripper-swarm.webp', true, true),
  ('tyranids_biovore', 'Biovore', 'tyranids-biovore', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Biovore card from the Tyranids test faction.', 'Test rules for Biovore; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-biovore.webp', true, true),
  ('tyranids_exocrine', 'Exocrine', 'tyranids-exocrine', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Exocrine card from the Tyranids test faction.', 'Test rules for Exocrine; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-exocrine.webp', true, true),
  ('tyranids_screamer_killer', 'Screamer-Killer', 'tyranids-screamer-killer', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='epic'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 6, 'A Screamer-Killer card from the Tyranids test faction.', 'Test rules for Screamer-Killer; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-screamer-killer.webp', true, true),
  ('tyranids_gargoyle_flock', 'Gargoyle Flock', 'tyranids-gargoyle-flock', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 2, 'A Gargoyle Flock card from the Tyranids test faction.', 'Test rules for Gargoyle Flock; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-gargoyle-flock.webp', true, true),
  ('tyranids_tervigon_broodmother', 'Tervigon Broodmother', 'tyranids-tervigon-broodmother', (SELECT id FROM card_types WHERE code='leader'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='epic'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 6, 'A Tervigon Broodmother card from the Tyranids test faction.', 'Test rules for Tervigon Broodmother; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-tervigon-broodmother.webp', true, true),
  ('tyranids_venomthrope_cloud', 'Venomthrope Cloud', 'tyranids-venomthrope-cloud', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Venomthrope Cloud card from the Tyranids test faction.', 'Test rules for Venomthrope Cloud; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-venomthrope-cloud.webp', true, true),
  ('tyranids_spore_mine_drift', 'Spore Mine Drift', 'tyranids-spore-mine-drift', (SELECT id FROM card_types WHERE code='tactic'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 1, 'A Spore Mine Drift card from the Tyranids test faction.', 'Test rules for Spore Mine Drift; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-spore-mine-drift.webp', true, true),
  ('tyranids_endless_swarm', 'Endless Swarm', 'tyranids-endless-swarm', (SELECT id FROM card_types WHERE code='doctrine'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Endless Swarm card from the Tyranids test faction.', 'Test rules for Endless Swarm; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-endless-swarm.webp', true, true),
  ('tyranids_digestive_acid', 'Digestive Acid', 'tyranids-digestive-acid', (SELECT id FROM card_types WHERE code='tactic'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 2, 'A Digestive Acid card from the Tyranids test faction.', 'Test rules for Digestive Acid; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-digestive-acid.webp', true, true),
  ('tyranids_adrenal_glands', 'Adrenal Glands', 'tyranids-adrenal-glands', (SELECT id FROM card_types WHERE code='wargear'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 1, 'A Adrenal Glands card from the Tyranids test faction.', 'Test rules for Adrenal Glands; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-adrenal-glands.webp', true, true),
  ('tyranids_chitinous_plates', 'Chitinous Plates', 'tyranids-chitinous-plates', (SELECT id FROM card_types WHERE code='wargear'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 2, 'A Chitinous Plates card from the Tyranids test faction.', 'Test rules for Chitinous Plates; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-chitinous-plates.webp', true, true),
  ('tyranids_hive_fleet_adaptation', 'Hive Fleet Adaptation', 'tyranids-hive-fleet-adaptation', (SELECT id FROM card_types WHERE code='doctrine'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='legendary'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Hive Fleet Adaptation card from the Tyranids test faction.', 'Test rules for Hive Fleet Adaptation; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-hive-fleet-adaptation.webp', true, true),
  ('tyranids_psychic_scream', 'Psychic Scream', 'tyranids-psychic-scream', (SELECT id FROM card_types WHERE code='tactic'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Psychic Scream card from the Tyranids test faction.', 'Test rules for Psychic Scream; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-psychic-scream.webp', true, true),
  ('tyranids_devourer_volley', 'Devourer Volley', 'tyranids-devourer-volley', (SELECT id FROM card_types WHERE code='tactic'), (SELECT id FROM factions WHERE code='tyranids'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 2, 'A Devourer Volley card from the Tyranids test faction.', 'Test rules for Devourer Volley; generated for read-model and cache experiments.', 'https://example.test/cards/tyranids-devourer-volley.webp', true, true),
  ('orks_boyz_mob', 'Boyz Mob', 'orks-boyz-mob', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 1, 'A Boyz Mob card from the Orks test faction.', 'Test rules for Boyz Mob; generated for read-model and cache experiments.', 'https://example.test/cards/orks-boyz-mob.webp', true, true),
  ('orks_shoota_boyz', 'Shoota Boyz', 'orks-shoota-boyz', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 2, 'A Shoota Boyz card from the Orks test faction.', 'Test rules for Shoota Boyz; generated for read-model and cache experiments.', 'https://example.test/cards/orks-shoota-boyz.webp', true, true),
  ('orks_nob_with_klaw', 'Nob with Klaw', 'orks-nob-with-klaw', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Nob with Klaw card from the Orks test faction.', 'Test rules for Nob with Klaw; generated for read-model and cache experiments.', 'https://example.test/cards/orks-nob-with-klaw.webp', true, true),
  ('orks_warboss', 'Warboss', 'orks-warboss', (SELECT id FROM card_types WHERE code='leader'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='legendary'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 6, 'A Warboss card from the Orks test faction.', 'Test rules for Warboss; generated for read-model and cache experiments.', 'https://example.test/cards/orks-warboss.webp', true, true),
  ('orks_big_mek', 'Big Mek', 'orks-big-mek', (SELECT id FROM card_types WHERE code='leader'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 4, 'A Big Mek card from the Orks test faction.', 'Test rules for Big Mek; generated for read-model and cache experiments.', 'https://example.test/cards/orks-big-mek.webp', true, true),
  ('orks_deff_dread', 'Deff Dread', 'orks-deff-dread', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Deff Dread card from the Orks test faction.', 'Test rules for Deff Dread; generated for read-model and cache experiments.', 'https://example.test/cards/orks-deff-dread.webp', true, true),
  ('orks_killa_kans', 'Killa Kans', 'orks-killa-kans', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Killa Kans card from the Orks test faction.', 'Test rules for Killa Kans; generated for read-model and cache experiments.', 'https://example.test/cards/orks-killa-kans.webp', true, true),
  ('orks_lootas', 'Lootas', 'orks-lootas', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Lootas card from the Orks test faction.', 'Test rules for Lootas; generated for read-model and cache experiments.', 'https://example.test/cards/orks-lootas.webp', true, true),
  ('orks_stormboyz', 'Stormboyz', 'orks-stormboyz', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Stormboyz card from the Orks test faction.', 'Test rules for Stormboyz; generated for read-model and cache experiments.', 'https://example.test/cards/orks-stormboyz.webp', true, true),
  ('orks_beast_snagga_boyz', 'Beast Snagga Boyz', 'orks-beast-snagga-boyz', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 2, 'A Beast Snagga Boyz card from the Orks test faction.', 'Test rules for Beast Snagga Boyz; generated for read-model and cache experiments.', 'https://example.test/cards/orks-beast-snagga-boyz.webp', true, true),
  ('orks_squighog_riders', 'Squighog Riders', 'orks-squighog-riders', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 4, 'A Squighog Riders card from the Orks test faction.', 'Test rules for Squighog Riders; generated for read-model and cache experiments.', 'https://example.test/cards/orks-squighog-riders.webp', true, true),
  ('orks_gretchin_screen', 'Gretchin Screen', 'orks-gretchin-screen', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 1, 'A Gretchin Screen card from the Orks test faction.', 'Test rules for Gretchin Screen; generated for read-model and cache experiments.', 'https://example.test/cards/orks-gretchin-screen.webp', true, true),
  ('orks_battlewagon', 'Battlewagon', 'orks-battlewagon', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='epic'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 6, 'A Battlewagon card from the Orks test faction.', 'Test rules for Battlewagon; generated for read-model and cache experiments.', 'https://example.test/cards/orks-battlewagon.webp', true, true),
  ('orks_meganobz', 'Meganobz', 'orks-meganobz', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Meganobz card from the Orks test faction.', 'Test rules for Meganobz; generated for read-model and cache experiments.', 'https://example.test/cards/orks-meganobz.webp', true, true),
  ('orks_weirdboy', 'Weirdboy', 'orks-weirdboy', (SELECT id FROM card_types WHERE code='leader'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='epic'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 4, 'A Weirdboy card from the Orks test faction.', 'Test rules for Weirdboy; generated for read-model and cache experiments.', 'https://example.test/cards/orks-weirdboy.webp', true, true),
  ('orks_kommandos', 'Kommandos', 'orks-kommandos', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Kommandos card from the Orks test faction.', 'Test rules for Kommandos; generated for read-model and cache experiments.', 'https://example.test/cards/orks-kommandos.webp', true, true),
  ('orks_flash_gitz', 'Flash Gitz', 'orks-flash-gitz', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='epic'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Flash Gitz card from the Orks test faction.', 'Test rules for Flash Gitz; generated for read-model and cache experiments.', 'https://example.test/cards/orks-flash-gitz.webp', true, true),
  ('orks_dakka_jet', 'Dakka Jet', 'orks-dakka-jet', (SELECT id FROM card_types WHERE code='unit'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Dakka Jet card from the Orks test faction.', 'Test rules for Dakka Jet; generated for read-model and cache experiments.', 'https://example.test/cards/orks-dakka-jet.webp', true, true),
  ('orks_waaagh_banner', 'Waaagh! Banner', 'orks-waaagh-banner', (SELECT id FROM card_types WHERE code='wargear'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='uncommon'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 2, 'A Waaagh! Banner card from the Orks test faction.', 'Test rules for Waaagh! Banner; generated for read-model and cache experiments.', 'https://example.test/cards/orks-waaagh-banner.webp', true, true),
  ('orks_kustom_force_field', 'Kustom Force Field', 'orks-kustom-force-field', (SELECT id FROM card_types WHERE code='wargear'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Kustom Force Field card from the Orks test faction.', 'Test rules for Kustom Force Field; generated for read-model and cache experiments.', 'https://example.test/cards/orks-kustom-force-field.webp', true, true),
  ('orks_rokkit_barrage', 'Rokkit Barrage', 'orks-rokkit-barrage', (SELECT id FROM card_types WHERE code='tactic'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 2, 'A Rokkit Barrage card from the Orks test faction.', 'Test rules for Rokkit Barrage; generated for read-model and cache experiments.', 'https://example.test/cards/orks-rokkit-barrage.webp', true, true),
  ('orks_green_tide', 'Green Tide', 'orks-green-tide', (SELECT id FROM card_types WHERE code='doctrine'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='epic'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 4, 'A Green Tide card from the Orks test faction.', 'Test rules for Green Tide; generated for read-model and cache experiments.', 'https://example.test/cards/orks-green-tide.webp', true, true),
  ('orks_brutal_kunnin', 'Brutal Kunnin', 'orks-brutal-kunnin', (SELECT id FROM card_types WHERE code='tactic'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='rare'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 3, 'A Brutal Kunnin card from the Orks test faction.', 'Test rules for Brutal Kunnin; generated for read-model and cache experiments.', 'https://example.test/cards/orks-brutal-kunnin.webp', true, true),
  ('orks_choppa_frenzy', 'Choppa Frenzy', 'orks-choppa-frenzy', (SELECT id FROM card_types WHERE code='tactic'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='common'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 1, 'A Choppa Frenzy card from the Orks test faction.', 'Test rules for Choppa Frenzy; generated for read-model and cache experiments.', 'https://example.test/cards/orks-choppa-frenzy.webp', true, true),
  ('orks_boss_pole_discipline', 'Boss Pole Discipline', 'orks-boss-pole-discipline', (SELECT id FROM card_types WHERE code='doctrine'), (SELECT id FROM factions WHERE code='orks'), (SELECT id FROM rarities WHERE code='legendary'), (SELECT id FROM card_sets WHERE code='core_41st_millennium'), 5, 'A Boss Pole Discipline card from the Orks test faction.', 'Test rules for Boss Pole Discipline; generated for read-model and cache experiments.', 'https://example.test/cards/orks-boss-pole-discipline.webp', true, true)
ON CONFLICT (code) DO UPDATE SET name=EXCLUDED.name, slug=EXCLUDED.slug, card_type_id=EXCLUDED.card_type_id, faction_id=EXCLUDED.faction_id, rarity_id=EXCLUDED.rarity_id, set_id=EXCLUDED.set_id, cost=EXCLUDED.cost, lore_text=EXCLUDED.lore_text, rules_text=EXCLUDED.rules_text, image_url=EXCLUDED.image_url, is_collectible=EXCLUDED.is_collectible, is_active=EXCLUDED.is_active, updated_at=now();

DELETE FROM card_combat_stats WHERE card_id IN (SELECT id FROM cards WHERE code IN ('adeptus_astartes_intercessor_squad','adeptus_astartes_assault_intercessors','adeptus_astartes_primaris_lieutenant','adeptus_astartes_redemptor_dreadnought','adeptus_astartes_terminator_squad','adeptus_astartes_bladeguard_veterans','adeptus_astartes_hellblaster_squad','adeptus_astartes_inceptor_squad','adeptus_astartes_captain_in_gravis_armor','adeptus_astartes_chaplain_orator','adeptus_astartes_librarian_epistolary','adeptus_astartes_aggressor_squad','adeptus_astartes_eradicator_squad','adeptus_astartes_repulsor_executioner','adeptus_astartes_impulsor_transport','adeptus_astartes_storm_speeder','adeptus_astartes_ancient_banner_bearer','adeptus_astartes_auspex_scan','adeptus_astartes_orbital_strike','adeptus_astartes_oath_of_moment','adeptus_astartes_purity_seal','adeptus_astartes_relic_blade','adeptus_astartes_storm_shield','adeptus_astartes_drop_pod_assault','adeptus_astartes_codex_discipline','tyranids_termagant_brood','tyranids_hormagaunt_swarm','tyranids_warrior_brood','tyranids_hive_tyrant','tyranids_carnifex','tyranids_tyrannofex','tyranids_zoanthrope_node','tyranids_genestealer_pack','tyranids_lictor_ambusher','tyranids_neurotyrant','tyranids_ripper_swarm','tyranids_biovore','tyranids_exocrine','tyranids_screamer_killer','tyranids_gargoyle_flock','tyranids_tervigon_broodmother','tyranids_venomthrope_cloud','tyranids_spore_mine_drift','tyranids_endless_swarm','tyranids_digestive_acid','tyranids_adrenal_glands','tyranids_chitinous_plates','tyranids_hive_fleet_adaptation','tyranids_psychic_scream','tyranids_devourer_volley','orks_boyz_mob','orks_shoota_boyz','orks_nob_with_klaw','orks_warboss','orks_big_mek','orks_deff_dread','orks_killa_kans','orks_lootas','orks_stormboyz','orks_beast_snagga_boyz','orks_squighog_riders','orks_gretchin_screen','orks_battlewagon','orks_meganobz','orks_weirdboy','orks_kommandos','orks_flash_gitz','orks_dakka_jet','orks_waaagh_banner','orks_kustom_force_field','orks_rokkit_barrage','orks_green_tide','orks_brutal_kunnin','orks_choppa_frenzy','orks_boss_pole_discipline'));
INSERT INTO card_combat_stats (card_id, attack, defense, health, speed, range, armor) VALUES
  ((SELECT id FROM cards WHERE code='adeptus_astartes_intercessor_squad'), 2, 2, 3, 2, 3, 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_assault_intercessors'), 3, 1, 3, 3, 1, 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_primaris_lieutenant'), 3, 3, 5, 2, 2, 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_redemptor_dreadnought'), 6, 5, 8, 1, 4, 3),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_terminator_squad'), 4, 5, 6, 1, 2, 3),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_bladeguard_veterans'), 4, 4, 5, 2, 1, 2),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_hellblaster_squad'), 5, 2, 4, 2, 4, 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_inceptor_squad'), 3, 2, 3, 4, 3, 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_captain_in_gravis_armor'), 5, 5, 7, 1, 2, 3),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_chaplain_orator'), 2, 4, 5, 2, 1, 2),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_librarian_epistolary'), 3, 3, 5, 2, 3, 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_aggressor_squad'), 4, 3, 5, 1, 3, 2),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_eradicator_squad'), 6, 2, 4, 1, 4, 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_repulsor_executioner'), 8, 6, 10, 1, 5, 4),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_impulsor_transport'), 2, 4, 6, 3, 2, 2),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_storm_speeder'), 5, 3, 5, 5, 4, 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_ancient_banner_bearer'), 2, 3, 4, 2, 1, 1),
  ((SELECT id FROM cards WHERE code='tyranids_termagant_brood'), 1, 1, 2, 2, 3, 0),
  ((SELECT id FROM cards WHERE code='tyranids_hormagaunt_swarm'), 2, 0, 2, 4, 1, 0),
  ((SELECT id FROM cards WHERE code='tyranids_warrior_brood'), 3, 3, 4, 2, 2, 1),
  ((SELECT id FROM cards WHERE code='tyranids_hive_tyrant'), 7, 6, 9, 3, 3, 3),
  ((SELECT id FROM cards WHERE code='tyranids_carnifex'), 6, 4, 8, 2, 1, 2),
  ((SELECT id FROM cards WHERE code='tyranids_tyrannofex'), 7, 5, 10, 1, 5, 3),
  ((SELECT id FROM cards WHERE code='tyranids_zoanthrope_node'), 3, 3, 5, 2, 4, 1),
  ((SELECT id FROM cards WHERE code='tyranids_genestealer_pack'), 4, 1, 3, 5, 1, 0),
  ((SELECT id FROM cards WHERE code='tyranids_lictor_ambusher'), 5, 2, 4, 5, 1, 1),
  ((SELECT id FROM cards WHERE code='tyranids_neurotyrant'), 3, 4, 6, 2, 4, 1),
  ((SELECT id FROM cards WHERE code='tyranids_ripper_swarm'), 1, 0, 1, 3, 1, 0),
  ((SELECT id FROM cards WHERE code='tyranids_biovore'), 2, 2, 3, 1, 5, 0),
  ((SELECT id FROM cards WHERE code='tyranids_exocrine'), 6, 3, 7, 1, 5, 2),
  ((SELECT id FROM cards WHERE code='tyranids_screamer_killer'), 7, 4, 8, 3, 1, 2),
  ((SELECT id FROM cards WHERE code='tyranids_gargoyle_flock'), 2, 1, 2, 5, 3, 0),
  ((SELECT id FROM cards WHERE code='tyranids_tervigon_broodmother'), 4, 5, 9, 1, 2, 2),
  ((SELECT id FROM cards WHERE code='tyranids_venomthrope_cloud'), 2, 3, 4, 2, 2, 1),
  ((SELECT id FROM cards WHERE code='orks_boyz_mob'), 2, 1, 2, 3, 1, 0),
  ((SELECT id FROM cards WHERE code='orks_shoota_boyz'), 2, 1, 2, 2, 3, 0),
  ((SELECT id FROM cards WHERE code='orks_nob_with_klaw'), 4, 2, 4, 2, 1, 1),
  ((SELECT id FROM cards WHERE code='orks_warboss'), 6, 4, 8, 3, 1, 2),
  ((SELECT id FROM cards WHERE code='orks_big_mek'), 3, 3, 5, 2, 3, 2),
  ((SELECT id FROM cards WHERE code='orks_deff_dread'), 6, 4, 7, 2, 1, 3),
  ((SELECT id FROM cards WHERE code='orks_killa_kans'), 3, 3, 4, 2, 2, 2),
  ((SELECT id FROM cards WHERE code='orks_lootas'), 4, 1, 3, 1, 5, 0),
  ((SELECT id FROM cards WHERE code='orks_stormboyz'), 3, 1, 3, 5, 1, 0),
  ((SELECT id FROM cards WHERE code='orks_beast_snagga_boyz'), 3, 1, 3, 3, 1, 0),
  ((SELECT id FROM cards WHERE code='orks_squighog_riders'), 5, 2, 5, 4, 1, 1),
  ((SELECT id FROM cards WHERE code='orks_gretchin_screen'), 1, 1, 1, 2, 2, 0),
  ((SELECT id FROM cards WHERE code='orks_battlewagon'), 5, 5, 9, 2, 3, 3),
  ((SELECT id FROM cards WHERE code='orks_meganobz'), 5, 4, 6, 1, 1, 3),
  ((SELECT id FROM cards WHERE code='orks_weirdboy'), 2, 2, 4, 2, 4, 0),
  ((SELECT id FROM cards WHERE code='orks_kommandos'), 3, 2, 3, 4, 2, 0),
  ((SELECT id FROM cards WHERE code='orks_flash_gitz'), 6, 2, 5, 2, 4, 1),
  ((SELECT id FROM cards WHERE code='orks_dakka_jet'), 5, 2, 5, 6, 5, 1)
ON CONFLICT (card_id) DO UPDATE SET attack=EXCLUDED.attack, defense=EXCLUDED.defense, health=EXCLUDED.health, speed=EXCLUDED.speed, range=EXCLUDED.range, armor=EXCLUDED.armor;

DELETE FROM card_tags WHERE card_id IN (SELECT id FROM cards WHERE code IN ('adeptus_astartes_intercessor_squad','adeptus_astartes_assault_intercessors','adeptus_astartes_primaris_lieutenant','adeptus_astartes_redemptor_dreadnought','adeptus_astartes_terminator_squad','adeptus_astartes_bladeguard_veterans','adeptus_astartes_hellblaster_squad','adeptus_astartes_inceptor_squad','adeptus_astartes_captain_in_gravis_armor','adeptus_astartes_chaplain_orator','adeptus_astartes_librarian_epistolary','adeptus_astartes_aggressor_squad','adeptus_astartes_eradicator_squad','adeptus_astartes_repulsor_executioner','adeptus_astartes_impulsor_transport','adeptus_astartes_storm_speeder','adeptus_astartes_ancient_banner_bearer','adeptus_astartes_auspex_scan','adeptus_astartes_orbital_strike','adeptus_astartes_oath_of_moment','adeptus_astartes_purity_seal','adeptus_astartes_relic_blade','adeptus_astartes_storm_shield','adeptus_astartes_drop_pod_assault','adeptus_astartes_codex_discipline','tyranids_termagant_brood','tyranids_hormagaunt_swarm','tyranids_warrior_brood','tyranids_hive_tyrant','tyranids_carnifex','tyranids_tyrannofex','tyranids_zoanthrope_node','tyranids_genestealer_pack','tyranids_lictor_ambusher','tyranids_neurotyrant','tyranids_ripper_swarm','tyranids_biovore','tyranids_exocrine','tyranids_screamer_killer','tyranids_gargoyle_flock','tyranids_tervigon_broodmother','tyranids_venomthrope_cloud','tyranids_spore_mine_drift','tyranids_endless_swarm','tyranids_digestive_acid','tyranids_adrenal_glands','tyranids_chitinous_plates','tyranids_hive_fleet_adaptation','tyranids_psychic_scream','tyranids_devourer_volley','orks_boyz_mob','orks_shoota_boyz','orks_nob_with_klaw','orks_warboss','orks_big_mek','orks_deff_dread','orks_killa_kans','orks_lootas','orks_stormboyz','orks_beast_snagga_boyz','orks_squighog_riders','orks_gretchin_screen','orks_battlewagon','orks_meganobz','orks_weirdboy','orks_kommandos','orks_flash_gitz','orks_dakka_jet','orks_waaagh_banner','orks_kustom_force_field','orks_rokkit_barrage','orks_green_tide','orks_brutal_kunnin','orks_choppa_frenzy','orks_boss_pole_discipline'));
INSERT INTO card_tags (card_id, tag_id) VALUES
  ((SELECT id FROM cards WHERE code='adeptus_astartes_intercessor_squad'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_intercessor_squad'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_assault_intercessors'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_assault_intercessors'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_primaris_lieutenant'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_primaris_lieutenant'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_redemptor_dreadnought'), (SELECT id FROM tags WHERE code='vehicle')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_redemptor_dreadnought'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_redemptor_dreadnought'), (SELECT id FROM tags WHERE code='machine')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_terminator_squad'), (SELECT id FROM tags WHERE code='terminator')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_terminator_squad'), (SELECT id FROM tags WHERE code='elite')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_terminator_squad'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_bladeguard_veterans'), (SELECT id FROM tags WHERE code='elite')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_bladeguard_veterans'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_bladeguard_veterans'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_hellblaster_squad'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_hellblaster_squad'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_hellblaster_squad'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_inceptor_squad'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_inceptor_squad'), (SELECT id FROM tags WHERE code='fast')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_inceptor_squad'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_captain_in_gravis_armor'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_captain_in_gravis_armor'), (SELECT id FROM tags WHERE code='elite')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_captain_in_gravis_armor'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_chaplain_orator'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_chaplain_orator'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_librarian_epistolary'), (SELECT id FROM tags WHERE code='psyker')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_librarian_epistolary'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_aggressor_squad'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_aggressor_squad'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_aggressor_squad'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_eradicator_squad'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_eradicator_squad'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_eradicator_squad'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_repulsor_executioner'), (SELECT id FROM tags WHERE code='vehicle')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_repulsor_executioner'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_repulsor_executioner'), (SELECT id FROM tags WHERE code='machine')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_impulsor_transport'), (SELECT id FROM tags WHERE code='vehicle')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_impulsor_transport'), (SELECT id FROM tags WHERE code='fast')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_impulsor_transport'), (SELECT id FROM tags WHERE code='machine')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_storm_speeder'), (SELECT id FROM tags WHERE code='vehicle')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_storm_speeder'), (SELECT id FROM tags WHERE code='fast')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_storm_speeder'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_ancient_banner_bearer'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_ancient_banner_bearer'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_auspex_scan'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_orbital_strike'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_orbital_strike'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_oath_of_moment'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_purity_seal'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_relic_blade'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_relic_blade'), (SELECT id FROM tags WHERE code='elite')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_storm_shield'), (SELECT id FROM tags WHERE code='elite')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_drop_pod_assault'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_drop_pod_assault'), (SELECT id FROM tags WHERE code='fast')),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_codex_discipline'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='tyranids_termagant_brood'), (SELECT id FROM tags WHERE code='swarm')),
  ((SELECT id FROM cards WHERE code='tyranids_termagant_brood'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='tyranids_termagant_brood'), (SELECT id FROM tags WHERE code='beast')),
  ((SELECT id FROM cards WHERE code='tyranids_hormagaunt_swarm'), (SELECT id FROM tags WHERE code='swarm')),
  ((SELECT id FROM cards WHERE code='tyranids_hormagaunt_swarm'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='tyranids_hormagaunt_swarm'), (SELECT id FROM tags WHERE code='beast')),
  ((SELECT id FROM cards WHERE code='tyranids_hormagaunt_swarm'), (SELECT id FROM tags WHERE code='fast')),
  ((SELECT id FROM cards WHERE code='tyranids_warrior_brood'), (SELECT id FROM tags WHERE code='synapse')),
  ((SELECT id FROM cards WHERE code='tyranids_warrior_brood'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='tyranids_warrior_brood'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='tyranids_hive_tyrant'), (SELECT id FROM tags WHERE code='synapse')),
  ((SELECT id FROM cards WHERE code='tyranids_hive_tyrant'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='tyranids_hive_tyrant'), (SELECT id FROM tags WHERE code='monster')),
  ((SELECT id FROM cards WHERE code='tyranids_hive_tyrant'), (SELECT id FROM tags WHERE code='psyker')),
  ((SELECT id FROM cards WHERE code='tyranids_carnifex'), (SELECT id FROM tags WHERE code='monster')),
  ((SELECT id FROM cards WHERE code='tyranids_carnifex'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='tyranids_carnifex'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='tyranids_tyrannofex'), (SELECT id FROM tags WHERE code='monster')),
  ((SELECT id FROM cards WHERE code='tyranids_tyrannofex'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='tyranids_tyrannofex'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='tyranids_zoanthrope_node'), (SELECT id FROM tags WHERE code='psyker')),
  ((SELECT id FROM cards WHERE code='tyranids_zoanthrope_node'), (SELECT id FROM tags WHERE code='synapse')),
  ((SELECT id FROM cards WHERE code='tyranids_genestealer_pack'), (SELECT id FROM tags WHERE code='beast')),
  ((SELECT id FROM cards WHERE code='tyranids_genestealer_pack'), (SELECT id FROM tags WHERE code='fast')),
  ((SELECT id FROM cards WHERE code='tyranids_genestealer_pack'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='tyranids_lictor_ambusher'), (SELECT id FROM tags WHERE code='beast')),
  ((SELECT id FROM cards WHERE code='tyranids_lictor_ambusher'), (SELECT id FROM tags WHERE code='elite')),
  ((SELECT id FROM cards WHERE code='tyranids_lictor_ambusher'), (SELECT id FROM tags WHERE code='fast')),
  ((SELECT id FROM cards WHERE code='tyranids_neurotyrant'), (SELECT id FROM tags WHERE code='psyker')),
  ((SELECT id FROM cards WHERE code='tyranids_neurotyrant'), (SELECT id FROM tags WHERE code='synapse')),
  ((SELECT id FROM cards WHERE code='tyranids_neurotyrant'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='tyranids_ripper_swarm'), (SELECT id FROM tags WHERE code='swarm')),
  ((SELECT id FROM cards WHERE code='tyranids_ripper_swarm'), (SELECT id FROM tags WHERE code='beast')),
  ((SELECT id FROM cards WHERE code='tyranids_biovore'), (SELECT id FROM tags WHERE code='beast')),
  ((SELECT id FROM cards WHERE code='tyranids_biovore'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='tyranids_exocrine'), (SELECT id FROM tags WHERE code='monster')),
  ((SELECT id FROM cards WHERE code='tyranids_exocrine'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='tyranids_exocrine'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='tyranids_screamer_killer'), (SELECT id FROM tags WHERE code='monster')),
  ((SELECT id FROM cards WHERE code='tyranids_screamer_killer'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='tyranids_screamer_killer'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='tyranids_gargoyle_flock'), (SELECT id FROM tags WHERE code='swarm')),
  ((SELECT id FROM cards WHERE code='tyranids_gargoyle_flock'), (SELECT id FROM tags WHERE code='fast')),
  ((SELECT id FROM cards WHERE code='tyranids_gargoyle_flock'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='tyranids_tervigon_broodmother'), (SELECT id FROM tags WHERE code='monster')),
  ((SELECT id FROM cards WHERE code='tyranids_tervigon_broodmother'), (SELECT id FROM tags WHERE code='synapse')),
  ((SELECT id FROM cards WHERE code='tyranids_tervigon_broodmother'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='tyranids_venomthrope_cloud'), (SELECT id FROM tags WHERE code='beast')),
  ((SELECT id FROM cards WHERE code='tyranids_venomthrope_cloud'), (SELECT id FROM tags WHERE code='synapse')),
  ((SELECT id FROM cards WHERE code='tyranids_spore_mine_drift'), (SELECT id FROM tags WHERE code='swarm')),
  ((SELECT id FROM cards WHERE code='tyranids_endless_swarm'), (SELECT id FROM tags WHERE code='swarm')),
  ((SELECT id FROM cards WHERE code='tyranids_digestive_acid'), (SELECT id FROM tags WHERE code='beast')),
  ((SELECT id FROM cards WHERE code='tyranids_adrenal_glands'), (SELECT id FROM tags WHERE code='fast')),
  ((SELECT id FROM cards WHERE code='tyranids_adrenal_glands'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='tyranids_chitinous_plates'), (SELECT id FROM tags WHERE code='monster')),
  ((SELECT id FROM cards WHERE code='tyranids_hive_fleet_adaptation'), (SELECT id FROM tags WHERE code='synapse')),
  ((SELECT id FROM cards WHERE code='tyranids_psychic_scream'), (SELECT id FROM tags WHERE code='psyker')),
  ((SELECT id FROM cards WHERE code='tyranids_devourer_volley'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='tyranids_devourer_volley'), (SELECT id FROM tags WHERE code='swarm')),
  ((SELECT id FROM cards WHERE code='orks_boyz_mob'), (SELECT id FROM tags WHERE code='boyz')),
  ((SELECT id FROM cards WHERE code='orks_boyz_mob'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='orks_boyz_mob'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='orks_shoota_boyz'), (SELECT id FROM tags WHERE code='boyz')),
  ((SELECT id FROM cards WHERE code='orks_shoota_boyz'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='orks_shoota_boyz'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='orks_nob_with_klaw'), (SELECT id FROM tags WHERE code='nob')),
  ((SELECT id FROM cards WHERE code='orks_nob_with_klaw'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='orks_nob_with_klaw'), (SELECT id FROM tags WHERE code='elite')),
  ((SELECT id FROM cards WHERE code='orks_warboss'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='orks_warboss'), (SELECT id FROM tags WHERE code='nob')),
  ((SELECT id FROM cards WHERE code='orks_warboss'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='orks_big_mek'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='orks_big_mek'), (SELECT id FROM tags WHERE code='machine')),
  ((SELECT id FROM cards WHERE code='orks_big_mek'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='orks_deff_dread'), (SELECT id FROM tags WHERE code='vehicle')),
  ((SELECT id FROM cards WHERE code='orks_deff_dread'), (SELECT id FROM tags WHERE code='machine')),
  ((SELECT id FROM cards WHERE code='orks_deff_dread'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='orks_killa_kans'), (SELECT id FROM tags WHERE code='vehicle')),
  ((SELECT id FROM cards WHERE code='orks_killa_kans'), (SELECT id FROM tags WHERE code='machine')),
  ((SELECT id FROM cards WHERE code='orks_killa_kans'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='orks_lootas'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='orks_lootas'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='orks_lootas'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='orks_stormboyz'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='orks_stormboyz'), (SELECT id FROM tags WHERE code='fast')),
  ((SELECT id FROM cards WHERE code='orks_stormboyz'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='orks_beast_snagga_boyz'), (SELECT id FROM tags WHERE code='beast_snagga')),
  ((SELECT id FROM cards WHERE code='orks_beast_snagga_boyz'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='orks_beast_snagga_boyz'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='orks_squighog_riders'), (SELECT id FROM tags WHERE code='beast_snagga')),
  ((SELECT id FROM cards WHERE code='orks_squighog_riders'), (SELECT id FROM tags WHERE code='fast')),
  ((SELECT id FROM cards WHERE code='orks_squighog_riders'), (SELECT id FROM tags WHERE code='beast')),
  ((SELECT id FROM cards WHERE code='orks_gretchin_screen'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='orks_gretchin_screen'), (SELECT id FROM tags WHERE code='swarm')),
  ((SELECT id FROM cards WHERE code='orks_gretchin_screen'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='orks_battlewagon'), (SELECT id FROM tags WHERE code='vehicle')),
  ((SELECT id FROM cards WHERE code='orks_battlewagon'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='orks_battlewagon'), (SELECT id FROM tags WHERE code='machine')),
  ((SELECT id FROM cards WHERE code='orks_meganobz'), (SELECT id FROM tags WHERE code='nob')),
  ((SELECT id FROM cards WHERE code='orks_meganobz'), (SELECT id FROM tags WHERE code='elite')),
  ((SELECT id FROM cards WHERE code='orks_meganobz'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='orks_weirdboy'), (SELECT id FROM tags WHERE code='psyker')),
  ((SELECT id FROM cards WHERE code='orks_weirdboy'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='orks_kommandos'), (SELECT id FROM tags WHERE code='infantry')),
  ((SELECT id FROM cards WHERE code='orks_kommandos'), (SELECT id FROM tags WHERE code='fast')),
  ((SELECT id FROM cards WHERE code='orks_kommandos'), (SELECT id FROM tags WHERE code='elite')),
  ((SELECT id FROM cards WHERE code='orks_flash_gitz'), (SELECT id FROM tags WHERE code='nob')),
  ((SELECT id FROM cards WHERE code='orks_flash_gitz'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='orks_flash_gitz'), (SELECT id FROM tags WHERE code='elite')),
  ((SELECT id FROM cards WHERE code='orks_dakka_jet'), (SELECT id FROM tags WHERE code='vehicle')),
  ((SELECT id FROM cards WHERE code='orks_dakka_jet'), (SELECT id FROM tags WHERE code='fast')),
  ((SELECT id FROM cards WHERE code='orks_dakka_jet'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='orks_waaagh_banner'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='orks_waaagh_banner'), (SELECT id FROM tags WHERE code='boyz')),
  ((SELECT id FROM cards WHERE code='orks_kustom_force_field'), (SELECT id FROM tags WHERE code='machine')),
  ((SELECT id FROM cards WHERE code='orks_rokkit_barrage'), (SELECT id FROM tags WHERE code='ranged')),
  ((SELECT id FROM cards WHERE code='orks_rokkit_barrage'), (SELECT id FROM tags WHERE code='heavy')),
  ((SELECT id FROM cards WHERE code='orks_green_tide'), (SELECT id FROM tags WHERE code='boyz')),
  ((SELECT id FROM cards WHERE code='orks_green_tide'), (SELECT id FROM tags WHERE code='swarm')),
  ((SELECT id FROM cards WHERE code='orks_brutal_kunnin'), (SELECT id FROM tags WHERE code='elite')),
  ((SELECT id FROM cards WHERE code='orks_choppa_frenzy'), (SELECT id FROM tags WHERE code='melee')),
  ((SELECT id FROM cards WHERE code='orks_boss_pole_discipline'), (SELECT id FROM tags WHERE code='commander')),
  ((SELECT id FROM cards WHERE code='orks_boss_pole_discipline'), (SELECT id FROM tags WHERE code='nob'))
ON CONFLICT DO NOTHING;

DELETE FROM card_abilities WHERE card_id IN (SELECT id FROM cards WHERE code IN ('adeptus_astartes_intercessor_squad','adeptus_astartes_assault_intercessors','adeptus_astartes_primaris_lieutenant','adeptus_astartes_redemptor_dreadnought','adeptus_astartes_terminator_squad','adeptus_astartes_bladeguard_veterans','adeptus_astartes_hellblaster_squad','adeptus_astartes_inceptor_squad','adeptus_astartes_captain_in_gravis_armor','adeptus_astartes_chaplain_orator','adeptus_astartes_librarian_epistolary','adeptus_astartes_aggressor_squad','adeptus_astartes_eradicator_squad','adeptus_astartes_repulsor_executioner','adeptus_astartes_impulsor_transport','adeptus_astartes_storm_speeder','adeptus_astartes_ancient_banner_bearer','adeptus_astartes_auspex_scan','adeptus_astartes_orbital_strike','adeptus_astartes_oath_of_moment','adeptus_astartes_purity_seal','adeptus_astartes_relic_blade','adeptus_astartes_storm_shield','adeptus_astartes_drop_pod_assault','adeptus_astartes_codex_discipline','tyranids_termagant_brood','tyranids_hormagaunt_swarm','tyranids_warrior_brood','tyranids_hive_tyrant','tyranids_carnifex','tyranids_tyrannofex','tyranids_zoanthrope_node','tyranids_genestealer_pack','tyranids_lictor_ambusher','tyranids_neurotyrant','tyranids_ripper_swarm','tyranids_biovore','tyranids_exocrine','tyranids_screamer_killer','tyranids_gargoyle_flock','tyranids_tervigon_broodmother','tyranids_venomthrope_cloud','tyranids_spore_mine_drift','tyranids_endless_swarm','tyranids_digestive_acid','tyranids_adrenal_glands','tyranids_chitinous_plates','tyranids_hive_fleet_adaptation','tyranids_psychic_scream','tyranids_devourer_volley','orks_boyz_mob','orks_shoota_boyz','orks_nob_with_klaw','orks_warboss','orks_big_mek','orks_deff_dread','orks_killa_kans','orks_lootas','orks_stormboyz','orks_beast_snagga_boyz','orks_squighog_riders','orks_gretchin_screen','orks_battlewagon','orks_meganobz','orks_weirdboy','orks_kommandos','orks_flash_gitz','orks_dakka_jet','orks_waaagh_banner','orks_kustom_force_field','orks_rokkit_barrage','orks_green_tide','orks_brutal_kunnin','orks_choppa_frenzy','orks_boss_pole_discipline'));
INSERT INTO card_abilities (card_id, ability_id, sort_order) VALUES
  ((SELECT id FROM cards WHERE code='adeptus_astartes_intercessor_squad'), (SELECT id FROM abilities WHERE code='bolter_drill'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_assault_intercessors'), (SELECT id FROM abilities WHERE code='and_they_shall_know_no_fear'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_primaris_lieutenant'), (SELECT id FROM abilities WHERE code='bolter_drill'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_primaris_lieutenant'), (SELECT id FROM abilities WHERE code='iron_halo'), 2),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_redemptor_dreadnought'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_terminator_squad'), (SELECT id FROM abilities WHERE code='deep_strike'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_terminator_squad'), (SELECT id FROM abilities WHERE code='iron_halo'), 2),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_bladeguard_veterans'), (SELECT id FROM abilities WHERE code='and_they_shall_know_no_fear'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_hellblaster_squad'), (SELECT id FROM abilities WHERE code='bolter_drill'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_inceptor_squad'), (SELECT id FROM abilities WHERE code='deep_strike'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_captain_in_gravis_armor'), (SELECT id FROM abilities WHERE code='iron_halo'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_captain_in_gravis_armor'), (SELECT id FROM abilities WHERE code='and_they_shall_know_no_fear'), 2),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_chaplain_orator'), (SELECT id FROM abilities WHERE code='and_they_shall_know_no_fear'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_librarian_epistolary'), (SELECT id FROM abilities WHERE code='shadow_in_the_warp'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_aggressor_squad'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_eradicator_squad'), (SELECT id FROM abilities WHERE code='bolter_drill'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_repulsor_executioner'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_repulsor_executioner'), (SELECT id FROM abilities WHERE code='iron_halo'), 2),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_impulsor_transport'), (SELECT id FROM abilities WHERE code='deep_strike'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_storm_speeder'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_ancient_banner_bearer'), (SELECT id FROM abilities WHERE code='and_they_shall_know_no_fear'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_auspex_scan'), (SELECT id FROM abilities WHERE code='bolter_drill'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_orbital_strike'), (SELECT id FROM abilities WHERE code='crushing_charge'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_oath_of_moment'), (SELECT id FROM abilities WHERE code='bolter_drill'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_purity_seal'), (SELECT id FROM abilities WHERE code='and_they_shall_know_no_fear'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_relic_blade'), (SELECT id FROM abilities WHERE code='crushing_charge'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_storm_shield'), (SELECT id FROM abilities WHERE code='iron_halo'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_drop_pod_assault'), (SELECT id FROM abilities WHERE code='deep_strike'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_codex_discipline'), (SELECT id FROM abilities WHERE code='and_they_shall_know_no_fear'), 1),
  ((SELECT id FROM cards WHERE code='adeptus_astartes_codex_discipline'), (SELECT id FROM abilities WHERE code='bolter_drill'), 2),
  ((SELECT id FROM cards WHERE code='tyranids_termagant_brood'), (SELECT id FROM abilities WHERE code='synaptic_link'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_hormagaunt_swarm'), (SELECT id FROM abilities WHERE code='crushing_charge'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_warrior_brood'), (SELECT id FROM abilities WHERE code='synaptic_link'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_hive_tyrant'), (SELECT id FROM abilities WHERE code='synaptic_link'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_hive_tyrant'), (SELECT id FROM abilities WHERE code='shadow_in_the_warp'), 2),
  ((SELECT id FROM cards WHERE code='tyranids_carnifex'), (SELECT id FROM abilities WHERE code='crushing_charge'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_carnifex'), (SELECT id FROM abilities WHERE code='regeneration'), 2),
  ((SELECT id FROM cards WHERE code='tyranids_tyrannofex'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_zoanthrope_node'), (SELECT id FROM abilities WHERE code='shadow_in_the_warp'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_genestealer_pack'), (SELECT id FROM abilities WHERE code='crushing_charge'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_lictor_ambusher'), (SELECT id FROM abilities WHERE code='deep_strike'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_neurotyrant'), (SELECT id FROM abilities WHERE code='shadow_in_the_warp'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_neurotyrant'), (SELECT id FROM abilities WHERE code='synaptic_link'), 2),
  ((SELECT id FROM cards WHERE code='tyranids_ripper_swarm'), (SELECT id FROM abilities WHERE code='regeneration'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_biovore'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_exocrine'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_screamer_killer'), (SELECT id FROM abilities WHERE code='crushing_charge'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_gargoyle_flock'), (SELECT id FROM abilities WHERE code='deep_strike'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_tervigon_broodmother'), (SELECT id FROM abilities WHERE code='regeneration'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_venomthrope_cloud'), (SELECT id FROM abilities WHERE code='shadow_in_the_warp'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_spore_mine_drift'), (SELECT id FROM abilities WHERE code='crushing_charge'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_endless_swarm'), (SELECT id FROM abilities WHERE code='synaptic_link'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_digestive_acid'), (SELECT id FROM abilities WHERE code='crushing_charge'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_adrenal_glands'), (SELECT id FROM abilities WHERE code='crushing_charge'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_chitinous_plates'), (SELECT id FROM abilities WHERE code='regeneration'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_hive_fleet_adaptation'), (SELECT id FROM abilities WHERE code='synaptic_link'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_hive_fleet_adaptation'), (SELECT id FROM abilities WHERE code='regeneration'), 2),
  ((SELECT id FROM cards WHERE code='tyranids_psychic_scream'), (SELECT id FROM abilities WHERE code='shadow_in_the_warp'), 1),
  ((SELECT id FROM cards WHERE code='tyranids_devourer_volley'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='orks_boyz_mob'), (SELECT id FROM abilities WHERE code='waaagh'), 1),
  ((SELECT id FROM cards WHERE code='orks_shoota_boyz'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='orks_nob_with_klaw'), (SELECT id FROM abilities WHERE code='crushing_charge'), 1),
  ((SELECT id FROM cards WHERE code='orks_warboss'), (SELECT id FROM abilities WHERE code='waaagh'), 1),
  ((SELECT id FROM cards WHERE code='orks_warboss'), (SELECT id FROM abilities WHERE code='crushing_charge'), 2),
  ((SELECT id FROM cards WHERE code='orks_big_mek'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='orks_big_mek'), (SELECT id FROM abilities WHERE code='iron_halo'), 2),
  ((SELECT id FROM cards WHERE code='orks_deff_dread'), (SELECT id FROM abilities WHERE code='crushing_charge'), 1),
  ((SELECT id FROM cards WHERE code='orks_killa_kans'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='orks_lootas'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='orks_stormboyz'), (SELECT id FROM abilities WHERE code='deep_strike'), 1),
  ((SELECT id FROM cards WHERE code='orks_beast_snagga_boyz'), (SELECT id FROM abilities WHERE code='crushing_charge'), 1),
  ((SELECT id FROM cards WHERE code='orks_squighog_riders'), (SELECT id FROM abilities WHERE code='crushing_charge'), 1),
  ((SELECT id FROM cards WHERE code='orks_battlewagon'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='orks_meganobz'), (SELECT id FROM abilities WHERE code='iron_halo'), 1),
  ((SELECT id FROM cards WHERE code='orks_weirdboy'), (SELECT id FROM abilities WHERE code='shadow_in_the_warp'), 1),
  ((SELECT id FROM cards WHERE code='orks_weirdboy'), (SELECT id FROM abilities WHERE code='waaagh'), 2),
  ((SELECT id FROM cards WHERE code='orks_kommandos'), (SELECT id FROM abilities WHERE code='deep_strike'), 1),
  ((SELECT id FROM cards WHERE code='orks_flash_gitz'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='orks_dakka_jet'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='orks_waaagh_banner'), (SELECT id FROM abilities WHERE code='waaagh'), 1),
  ((SELECT id FROM cards WHERE code='orks_kustom_force_field'), (SELECT id FROM abilities WHERE code='iron_halo'), 1),
  ((SELECT id FROM cards WHERE code='orks_rokkit_barrage'), (SELECT id FROM abilities WHERE code='more_dakka'), 1),
  ((SELECT id FROM cards WHERE code='orks_green_tide'), (SELECT id FROM abilities WHERE code='waaagh'), 1),
  ((SELECT id FROM cards WHERE code='orks_brutal_kunnin'), (SELECT id FROM abilities WHERE code='deep_strike'), 1),
  ((SELECT id FROM cards WHERE code='orks_choppa_frenzy'), (SELECT id FROM abilities WHERE code='waaagh'), 1),
  ((SELECT id FROM cards WHERE code='orks_boss_pole_discipline'), (SELECT id FROM abilities WHERE code='waaagh'), 1),
  ((SELECT id FROM cards WHERE code='orks_boss_pole_discipline'), (SELECT id FROM abilities WHERE code='and_they_shall_know_no_fear'), 2)
ON CONFLICT (card_id, ability_id) DO UPDATE SET sort_order=EXCLUDED.sort_order;

INSERT INTO card_balance_versions (card_id, version, cost, attack, defense, health, valid_from, valid_to, change_note)
SELECT c.id, 1, c.cost, cs.attack, cs.defense, cs.health, now(), NULL, 'Initial bootstrap balance'
FROM cards c
LEFT JOIN card_combat_stats cs ON cs.card_id = c.id
WHERE c.code IN ('adeptus_astartes_intercessor_squad','adeptus_astartes_assault_intercessors','adeptus_astartes_primaris_lieutenant','adeptus_astartes_redemptor_dreadnought','adeptus_astartes_terminator_squad','adeptus_astartes_bladeguard_veterans','adeptus_astartes_hellblaster_squad','adeptus_astartes_inceptor_squad','adeptus_astartes_captain_in_gravis_armor','adeptus_astartes_chaplain_orator','adeptus_astartes_librarian_epistolary','adeptus_astartes_aggressor_squad','adeptus_astartes_eradicator_squad','adeptus_astartes_repulsor_executioner','adeptus_astartes_impulsor_transport','adeptus_astartes_storm_speeder','adeptus_astartes_ancient_banner_bearer','adeptus_astartes_auspex_scan','adeptus_astartes_orbital_strike','adeptus_astartes_oath_of_moment','adeptus_astartes_purity_seal','adeptus_astartes_relic_blade','adeptus_astartes_storm_shield','adeptus_astartes_drop_pod_assault','adeptus_astartes_codex_discipline','tyranids_termagant_brood','tyranids_hormagaunt_swarm','tyranids_warrior_brood','tyranids_hive_tyrant','tyranids_carnifex','tyranids_tyrannofex','tyranids_zoanthrope_node','tyranids_genestealer_pack','tyranids_lictor_ambusher','tyranids_neurotyrant','tyranids_ripper_swarm','tyranids_biovore','tyranids_exocrine','tyranids_screamer_killer','tyranids_gargoyle_flock','tyranids_tervigon_broodmother','tyranids_venomthrope_cloud','tyranids_spore_mine_drift','tyranids_endless_swarm','tyranids_digestive_acid','tyranids_adrenal_glands','tyranids_chitinous_plates','tyranids_hive_fleet_adaptation','tyranids_psychic_scream','tyranids_devourer_volley','orks_boyz_mob','orks_shoota_boyz','orks_nob_with_klaw','orks_warboss','orks_big_mek','orks_deff_dread','orks_killa_kans','orks_lootas','orks_stormboyz','orks_beast_snagga_boyz','orks_squighog_riders','orks_gretchin_screen','orks_battlewagon','orks_meganobz','orks_weirdboy','orks_kommandos','orks_flash_gitz','orks_dakka_jet','orks_waaagh_banner','orks_kustom_force_field','orks_rokkit_barrage','orks_green_tide','orks_brutal_kunnin','orks_choppa_frenzy','orks_boss_pole_discipline')
ON CONFLICT (card_id, version) DO UPDATE SET cost=EXCLUDED.cost, attack=EXCLUDED.attack, defense=EXCLUDED.defense, health=EXCLUDED.health, valid_to=NULL, change_note=EXCLUDED.change_note;

-- Rebuild card detail projection for seeded cards.
INSERT INTO projection_cards (
  card_uuid, card_code, name, slug, type_code, type_name, faction_code, faction_name,
  rarity_code, rarity_name, set_code, set_name, cost, attack, defense, health, speed, range, armor,
  tags, abilities, searchable_text, power_score, is_collectible, is_active, updated_at
)
SELECT
  c.uuid, c.code, c.name, c.slug, ct.code, ct.name, f.code, f.name,
  r.code, r.name, s.code, s.name, c.cost,
  cs.attack, cs.defense, cs.health, cs.speed, cs.range, cs.armor,
  COALESCE(tj.tags, '[]'::jsonb) AS tags,
  COALESCE(aj.abilities, '[]'::jsonb) AS abilities,
  lower(concat_ws(' ', c.name, c.code, f.name, ct.name, r.name, c.lore_text, c.rules_text, tj.tag_text, aj.ability_text)) AS searchable_text,
  CASE
    WHEN cs.card_id IS NULL THEN c.cost::numeric
    ELSE round((c.cost + cs.attack * 1.6 + cs.defense * 1.2 + cs.health * 1.1 + cs.speed * 0.5 + cs.range * 0.4 + cs.armor * 1.5)::numeric, 2)
  END AS power_score,
  c.is_collectible, c.is_active, now()
FROM cards c
JOIN card_types ct ON ct.id = c.card_type_id
JOIN factions f ON f.id = c.faction_id
JOIN rarities r ON r.id = c.rarity_id
JOIN card_sets s ON s.id = c.set_id
LEFT JOIN card_combat_stats cs ON cs.card_id = c.id
LEFT JOIN LATERAL (
  SELECT
    jsonb_agg(jsonb_build_object('code', t.code, 'name', t.name) ORDER BY t.code) AS tags,
    string_agg(t.name, ' ') AS tag_text
  FROM card_tags ctag
  JOIN tags t ON t.id = ctag.tag_id
  WHERE ctag.card_id = c.id
) tj ON true
LEFT JOIN LATERAL (
  SELECT
    jsonb_agg(jsonb_build_object(
      'code', a.code,
      'name', a.name,
      'trigger', att.code,
      'effect', aet.code,
      'description', a.description
    ) ORDER BY ca.sort_order, a.code) AS abilities,
    string_agg(a.name || ' ' || a.description, ' ') AS ability_text
  FROM card_abilities ca
  JOIN abilities a ON a.id = ca.ability_id
  JOIN ability_trigger_types att ON att.id = a.trigger_type_id
  JOIN ability_effect_types aet ON aet.id = a.effect_type_id
  WHERE ca.card_id = c.id
) aj ON true
WHERE f.code IN ('adeptus_astartes', 'tyranids', 'orks')
ON CONFLICT (card_uuid) DO UPDATE SET
  card_code=EXCLUDED.card_code,
  name=EXCLUDED.name,
  slug=EXCLUDED.slug,
  type_code=EXCLUDED.type_code,
  type_name=EXCLUDED.type_name,
  faction_code=EXCLUDED.faction_code,
  faction_name=EXCLUDED.faction_name,
  rarity_code=EXCLUDED.rarity_code,
  rarity_name=EXCLUDED.rarity_name,
  set_code=EXCLUDED.set_code,
  set_name=EXCLUDED.set_name,
  cost=EXCLUDED.cost,
  attack=EXCLUDED.attack,
  defense=EXCLUDED.defense,
  health=EXCLUDED.health,
  speed=EXCLUDED.speed,
  range=EXCLUDED.range,
  armor=EXCLUDED.armor,
  tags=EXCLUDED.tags,
  abilities=EXCLUDED.abilities,
  searchable_text=EXCLUDED.searchable_text,
  power_score=EXCLUDED.power_score,
  is_collectible=EXCLUDED.is_collectible,
  is_active=EXCLUDED.is_active,
  updated_at=now();

INSERT INTO projection_card_lists (
  card_uuid, name, slug, type_code, faction_code, rarity_code, set_code, cost,
  attack, defense, health, power_score, tags, is_active, updated_at
)
SELECT
  pc.card_uuid, pc.name, pc.slug, pc.type_code, pc.faction_code, pc.rarity_code, pc.set_code, pc.cost,
  pc.attack, pc.defense, pc.health, pc.power_score,
  COALESCE((SELECT array_agg(x->>'code' ORDER BY x->>'code') FROM jsonb_array_elements(pc.tags) x), '{}') AS tags,
  pc.is_active, now()
FROM projection_cards pc
WHERE pc.faction_code IN ('adeptus_astartes', 'tyranids', 'orks')
ON CONFLICT (card_uuid) DO UPDATE SET
  name=EXCLUDED.name,
  slug=EXCLUDED.slug,
  type_code=EXCLUDED.type_code,
  faction_code=EXCLUDED.faction_code,
  rarity_code=EXCLUDED.rarity_code,
  set_code=EXCLUDED.set_code,
  cost=EXCLUDED.cost,
  attack=EXCLUDED.attack,
  defense=EXCLUDED.defense,
  health=EXCLUDED.health,
  power_score=EXCLUDED.power_score,
  tags=EXCLUDED.tags,
  is_active=EXCLUDED.is_active,
  updated_at=now();

INSERT INTO projection_faction_card_stats (
  faction_code, faction_name, total_cards, total_units, total_tactics, avg_cost,
  avg_attack, avg_defense, legendary_count, tag_distribution, updated_at
)
SELECT
  pc.faction_code,
  pc.faction_name,
  count(*)::int AS total_cards,
  count(*) FILTER (WHERE pc.type_code = 'unit')::int AS total_units,
  count(*) FILTER (WHERE pc.type_code = 'tactic')::int AS total_tactics,
  round(avg(pc.cost)::numeric, 2) AS avg_cost,
  round(avg(pc.attack)::numeric, 2) AS avg_attack,
  round(avg(pc.defense)::numeric, 2) AS avg_defense,
  count(*) FILTER (WHERE pc.rarity_code = 'legendary')::int AS legendary_count,
  COALESCE(td.tag_distribution, '{}'::jsonb) AS tag_distribution,
  now()
FROM projection_cards pc
LEFT JOIN LATERAL (
  SELECT jsonb_object_agg(tag_code, tag_count ORDER BY tag_code) AS tag_distribution
  FROM (
    SELECT tag_elem->>'code' AS tag_code, count(*) AS tag_count
    FROM projection_cards pc2
    CROSS JOIN LATERAL jsonb_array_elements(pc2.tags) tag_elem
    WHERE pc2.faction_code = pc.faction_code
    GROUP BY tag_elem->>'code'
  ) x
) td ON true
WHERE pc.faction_code IN ('adeptus_astartes', 'tyranids', 'orks')
GROUP BY pc.faction_code, pc.faction_name, td.tag_distribution
ON CONFLICT (faction_code) DO UPDATE SET
  faction_name=EXCLUDED.faction_name,
  total_cards=EXCLUDED.total_cards,
  total_units=EXCLUDED.total_units,
  total_tactics=EXCLUDED.total_tactics,
  avg_cost=EXCLUDED.avg_cost,
  avg_attack=EXCLUDED.avg_attack,
  avg_defense=EXCLUDED.avg_defense,
  legendary_count=EXCLUDED.legendary_count,
  tag_distribution=EXCLUDED.tag_distribution,
  updated_at=now();

COMMIT;

-- Sanity checks:
-- SELECT faction_code, total_cards FROM projection_faction_card_stats ORDER BY faction_code;
-- SELECT faction_code, count(*) FROM projection_cards GROUP BY faction_code ORDER BY faction_code;
