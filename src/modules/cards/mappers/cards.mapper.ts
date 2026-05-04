import { Injectable } from '@nestjs/common';
import { CardModel } from '../models/card.model';
import { CardRow } from '../repositories/cards.pg.repository';

@Injectable()
export class CardsMapper {
    cardRowToCardModel(cardRow: CardRow): CardModel {
        return {
            uuid: cardRow.card_uuid,
            code: cardRow.card_code,
            name: cardRow.name,
            slug: cardRow.slug,

            typeCode: cardRow.type_code,
            typeName: cardRow.type_name,

            factionCode: cardRow.faction_code,
            factionName: cardRow.faction_name,

            rarityCode: cardRow.rarity_code,
            rarityName: cardRow.rarity_name,

            cost: cardRow.cost,

            stats:
                cardRow.attack !== null &&
                cardRow.defense !== null &&
                cardRow.health !== null &&
                cardRow.speed !== null &&
                cardRow.range !== null &&
                cardRow.armor !== null
                    ? {
                          attack: cardRow.attack,
                          defense: cardRow.defense,
                          health: cardRow.health,
                          speed: cardRow.speed,
                          range: cardRow.range,
                          armor: cardRow.armor,
                      }
                    : undefined,

            tags: cardRow.tags.map((tag) => ({
                code: tag.code,
                name: tag.name,
            })),

            abilities: cardRow.abilities.map((ability) => ({
                code: ability.code,
                name: ability.name,
                trigger: ability.trigger,
                effect: ability.effect,
                description: ability.description,
            })),

            rulesText: cardRow.rules_text ?? undefined,
            loreText: cardRow.lore_text ?? undefined,
            imageUrl: cardRow.image_url ?? undefined,

            powerScore: typeof cardRow.power_score === 'string' ? parseFloat(cardRow.power_score) : cardRow.power_score,

            isCollectible: cardRow.is_collectible,
            isActive: cardRow.is_active,
        };
    }
}
