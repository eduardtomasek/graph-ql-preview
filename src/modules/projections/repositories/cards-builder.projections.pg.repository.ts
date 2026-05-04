import { Inject, Injectable } from '@nestjs/common';
import * as pgp from 'pg-promise';
import { MAIN_PG_CONNECTION } from 'src/libs/core/constants';
import { CardRow } from '../../cards/interfaces/card-row.interface';

@Injectable()
export class CardsBuilderProjectionsPgRepository {
    constructor(
        @Inject(MAIN_PG_CONNECTION)
        private readonly db: pgp.IDatabase<any>,
    ) {}

    findBySlug(slug: string): Promise<CardRow | null> {
        return this.db.oneOrNone<CardRow>(
            /* sql */ `
				SELECT
					c.uuid AS card_uuid,
					c.code AS card_code,
					c.name,
					c.slug,
					ct.code AS type_code,
					ct.name AS type_name,
					f.code AS faction_code,
					f.name AS faction_name,
					r.code AS rarity_code,
					r.name AS rarity_name,
					cs.code AS set_code,
					cs.name AS set_name,
					c.cost,
					css.attack,
					css.defense,
					css.health,
					css.speed,
					css.range,
					css.armor,
					COALESCE(
						jsonb_agg(
							DISTINCT jsonb_build_object(
								'code', t.code,
								'name', t.name
							)
						) FILTER (WHERE t.id IS NOT NULL),
						'[]'::jsonb
					) AS tags,
					COALESCE(
						jsonb_agg(
							DISTINCT jsonb_build_object(
								'code', a.code,
								'name', a.name,
								'trigger', att.code,
								'effect', aet.code,
								'description', a.description
							)
						) FILTER (WHERE a.id IS NOT NULL),
						'[]'::jsonb
					) AS abilities,
					c.rules_text,
					c.lore_text,
					c.image_url,
					(
						COALESCE(c.cost, 0) * 0.6
						+ COALESCE(css.attack, 0) * 1.2
						+ COALESCE(css.defense, 0) * 1.0
						+ COALESCE(css.health, 0) * 0.8
					)::numeric(10,2) AS power_score,
					c.is_collectible,
					c.is_active,
					c.updated_at
				FROM cards c
					JOIN card_types ct ON ct.id = c.card_type_id
					JOIN factions f ON f.id = c.faction_id
					JOIN rarities r ON r.id = c.rarity_id
					JOIN card_sets cs ON cs.id = c.set_id
					LEFT JOIN card_combat_stats css ON css.card_id = c.id
					LEFT JOIN card_tags ctag ON ctag.card_id = c.id
					LEFT JOIN tags t ON t.id = ctag.tag_id
					LEFT JOIN card_abilities ca ON ca.card_id = c.id
					LEFT JOIN abilities a ON a.id = ca.ability_id
					LEFT JOIN ability_trigger_types att ON att.id = a.trigger_type_id
					LEFT JOIN ability_effect_types aet ON aet.id = a.effect_type_id
					WHERE c.slug = $[slug]
				AND c.is_active = true
				GROUP BY
					c.id,
					ct.id,
					f.id,
					r.id,
					cs.code,
					cs.name,
					css.card_id,
					css.attack,
					css.defense,
					css.health,
					css.speed,
					css.range,
					css.armor
				LIMIT 1;
			`,
            { slug },
        );
    }

    findBySlugs(slugs: string[]): Promise<CardRow[]> {
        return this.db.manyOrNone<CardRow>(
            /* sql */ `
				SELECT
					c.uuid AS card_uuid,
					c.code AS card_code,
					c.name,
					c.slug,
					ct.code AS type_code,
					ct.name AS type_name,
					f.code AS faction_code,
					f.name AS faction_name,
					r.code AS rarity_code,
					r.name AS rarity_name,
					cs.code AS set_code,
					cs.name AS set_name,
					c.cost,
					css.attack,
					css.defense,
					css.health,
					css.speed,
					css.range,
					css.armor,
					COALESCE(
						jsonb_agg(
							DISTINCT jsonb_build_object(
								'code', t.code,
								'name', t.name
							)
						) FILTER (WHERE t.id IS NOT NULL),
						'[]'::jsonb
					) AS tags,
					COALESCE(
						jsonb_agg(
							DISTINCT jsonb_build_object(
								'code', a.code,
								'name', a.name,
								'trigger', att.code,
								'effect', aet.code,
								'description', a.description
							)
						) FILTER (WHERE a.id IS NOT NULL),
						'[]'::jsonb
					) AS abilities,
					c.rules_text,
					c.lore_text,
					c.image_url,
					(
						COALESCE(c.cost, 0) * 0.6
						+ COALESCE(css.attack, 0) * 1.2
						+ COALESCE(css.defense, 0) * 1.0
						+ COALESCE(css.health, 0) * 0.8
					)::numeric(10,2) AS power_score,
					c.is_collectible,
					c.is_active,
					c.updated_at
				FROM cards c
					JOIN card_types ct ON ct.id = c.card_type_id
					JOIN factions f ON f.id = c.faction_id
					JOIN rarities r ON r.id = c.rarity_id
					JOIN card_sets cs ON cs.id = c.set_id
					LEFT JOIN card_combat_stats css ON css.card_id = c.id
					LEFT JOIN card_tags ctag ON ctag.card_id = c.id
					LEFT JOIN tags t ON t.id = ctag.tag_id
					LEFT JOIN card_abilities ca ON ca.card_id = c.id
					LEFT JOIN abilities a ON a.id = ca.ability_id
					LEFT JOIN ability_trigger_types att ON att.id = a.trigger_type_id
					LEFT JOIN ability_effect_types aet ON aet.id = a.effect_type_id
					WHERE c.slug = ANY($[slugs]::text[])
				AND c.is_active = true
				GROUP BY
					c.id,
					ct.id,
					f.id,
					r.id,
					cs.code,
					cs.name,
					css.card_id,
					css.attack,
					css.defense,
					css.health,
					css.speed,
					css.range,
					css.armor

			`,
            { slugs },
        );
    }

    async storeCardProjections(cards: CardRow[]): Promise<void> {
        const pg = this.db.$config.pgp;

        const columnSet = new pg.helpers.ColumnSet(
            [
                { name: 'card_uuid', prop: 'card_uuid' },
                { name: 'card_code', prop: 'card_code' },
                { name: 'name', prop: 'name' },
                { name: 'slug', prop: 'slug' },
                { name: 'type_code', prop: 'type_code' },
                { name: 'type_name', prop: 'type_name' },
                { name: 'faction_code', prop: 'faction_code' },
                { name: 'faction_name', prop: 'faction_name' },
                { name: 'rarity_code', prop: 'rarity_code' },
                { name: 'rarity_name', prop: 'rarity_name' },
                { name: 'set_code', prop: 'set_code' },
                { name: 'set_name', prop: 'set_name' },
                { name: 'cost', prop: 'cost' },
                { name: 'attack', prop: 'attack' },
                { name: 'defense', prop: 'defense' },
                { name: 'health', prop: 'health' },
                { name: 'speed', prop: 'speed' },
                { name: 'range', prop: 'range' },
                { name: 'armor', prop: 'armor' },
                { name: 'tags', prop: 'tags', init: (col: { value: unknown }) => JSON.stringify(col.value) },
                { name: 'abilities', prop: 'abilities', init: (col: { value: unknown }) => JSON.stringify(col.value) },
                // lower(concat_ws(' ', c.name, c.code, f.name, ct.name, r.name, c.lore_text, c.rules_text, tj.tag_text, aj.ability_text)) AS searchable_text,
                {
                    name: 'searchable_text',
                    init: (col: { source: CardRow }) =>
                        [
                            col.source.name,
                            col.source.card_code,
                            col.source.faction_name,
                            col.source.type_name,
                            col.source.rarity_name,
                            col.source.rules_text,
                            col.source.lore_text,
                            ...col.source.tags.map((t) => t.name),
                            ...col.source.abilities.map((a) => `${a.name} ${a.description}`),
                        ]
                            .filter(Boolean)
                            .join(' ')
                            .toLowerCase(),
                },
                { name: 'power_score', prop: 'power_score' },
                { name: 'is_collectible', prop: 'is_collectible' },
                { name: 'is_active', prop: 'is_active' },
                { name: 'updated_at', prop: 'updated_at' },
            ],
            { table: 'projection_cards' },
        );

        const sql =
            pg.helpers.insert(cards, columnSet) +
            ` ON CONFLICT (slug) DO UPDATE SET
                card_uuid = EXCLUDED.card_uuid,
                card_code = EXCLUDED.card_code,
                name = EXCLUDED.name,
                type_code = EXCLUDED.type_code,
                type_name = EXCLUDED.type_name,
                faction_code = EXCLUDED.faction_code,
                faction_name = EXCLUDED.faction_name,
                rarity_code = EXCLUDED.rarity_code,
                rarity_name = EXCLUDED.rarity_name,
                set_code = EXCLUDED.set_code,
                set_name = EXCLUDED.set_name,
                cost = EXCLUDED.cost,
                attack = EXCLUDED.attack,
                defense = EXCLUDED.defense,
                health = EXCLUDED.health,
                speed = EXCLUDED.speed,
                range = EXCLUDED.range,
                armor = EXCLUDED.armor,
                tags = EXCLUDED.tags,
                abilities = EXCLUDED.abilities,
				searchable_text = EXCLUDED.searchable_text,
                power_score = EXCLUDED.power_score,
                is_collectible = EXCLUDED.is_collectible,
                is_active = EXCLUDED.is_active,
                updated_at = EXCLUDED.updated_at`;

        await this.db.none(sql);
    }
}
