import { Inject, Injectable } from '@nestjs/common';
import * as pgp from 'pg-promise';
import { MAIN_PG_CONNECTION } from 'src/libs/core/constants';
import { ProjectionCardRow } from '../interfaces/projection-card-row.interface';

@Injectable()
export class CardsProjectionsPgRepository {
    constructor(
        @Inject(MAIN_PG_CONNECTION)
        private readonly db: pgp.IDatabase<any>,
    ) {}

    async findBySlug(slug: string): Promise<ProjectionCardRow | null> {
        return this.db.oneOrNone<ProjectionCardRow>(
            /* sql */ `
        SELECT
            pc.card_uuid,
            pc.card_code,
            pc.name,
            pc.slug,

            pc.type_code,
            pc.type_name,

            pc.faction_code,
            pc.faction_name,

            pc.rarity_code,
            pc.rarity_name,

            pc.set_code,
            pc.set_name,
            pc.cost,

            pc.attack,
            pc.defense,
            pc.health,
            pc.speed,
            pc.range,
            pc.armor,

            COALESCE(pc.tags, '[]'::jsonb) AS tags,
            COALESCE(pc.abilities, '[]'::jsonb) AS abilities,

            pc.power_score,

            pc.is_collectible,
            pc.is_active,
            pc.updated_at
        FROM projection_cards pc
        WHERE pc.slug = $[slug]
          AND pc.is_active = true
        LIMIT 1;
      `,
            { slug },
        );
    }
}
