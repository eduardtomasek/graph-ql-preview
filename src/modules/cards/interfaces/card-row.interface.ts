import { CardAbilityRow } from './card-ability-row.interface';
import { CardTagRow } from './card-tag-row.interface';

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

    set_code: string;
    set_name: string;

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
