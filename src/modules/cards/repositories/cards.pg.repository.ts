import { Inject, Injectable } from '@nestjs/common';
import * as pgp from 'pg-promise';
import { MAIN_PG_CONNECTION } from '../../../libs/core/constants';

@Injectable()
export class CardsPgRepository {
    constructor(@Inject(MAIN_PG_CONNECTION) private readonly db: pgp.IDatabase<any>) {}

    findCardBySlug(slug: string): Promise<CardRow | null> {
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
				c.cost,
				cs.attack,
				cs.defense,
				cs.health,
				cs.speed,
				cs.range,
				cs.armor,
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
					+ COALESCE(cs.attack, 0) * 1.2
					+ COALESCE(cs.defense, 0) * 1.0
					+ COALESCE(cs.health, 0) * 0.8
				)::numeric(10,2) AS power_score,
				c.is_collectible,
				c.is_active,
				c.updated_at
			FROM cards c
				JOIN card_types ct ON ct.id = c.card_type_id
				JOIN factions f ON f.id = c.faction_id
				JOIN rarities r ON r.id = c.rarity_id
				LEFT JOIN card_combat_stats cs ON cs.card_id = c.id
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
				cs.card_id,
				cs.attack,
				cs.defense,
				cs.health,
				cs.speed,
				cs.range,
				cs.armor
			LIMIT 1;
		`,
            { slug },
        );
    }
}

export interface CardTagRow {
    code: string;
    name: string;
}

export interface CardAbilityRow {
    code: string;
    name: string;
    trigger: string;
    effect: string;
    description: string;
}

export interface CardRow {
    card_uuid: string;
    card_code: string;
    name: string;
    slug: string;

    type_code: string;
    type_name: string;

    faction_code: string;
    faction_name: string;

    rarity_code: string;
    rarity_name: string;

    cost: number;

    attack: number | null;
    defense: number | null;
    health: number | null;
    speed: number | null;
    range: number | null;
    armor: number | null;

    tags: CardTagRow[];
    abilities: CardAbilityRow[];

    rules_text: string | null;
    lore_text: string | null;
    image_url: string | null;

    power_score: string | number; // pg vrací numeric často jako string

    is_collectible: boolean;
    is_active: boolean;

    updated_at: string | Date;
}
