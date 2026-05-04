import { Args, Query, Resolver } from '@nestjs/graphql';
import { CardModel } from '../models/card.model';
import { CardsService } from '../services/cards.service';

@Resolver()
export class CardsResolver {
    constructor(private readonly cardsService: CardsService) {}

    /**
     * Example query to fetch a card by its slug.
     *
     * GraphQL Query:
     * query {
        card(slug: "adeptus-astartes-bladeguard-veterans") {
            uuid
            code
            name
            slug
            typeCode
            typeName
            factionCode
            factionName
            rarityCode
            rarityName
            cost
            stats {
                attack
                defense
                health
                speed
                range
                armor
            }
            tags {
                code
                name
            }
            abilities {
                code
                name
                trigger
                effect
                description
            }
            rulesText
            loreText
            imageUrl
            powerScore
            isCollectible
            isActive
        }
        }
     * @param slug
     * @returns
     */
    @Query(() => CardModel, { nullable: true })
    card(@Args('slug') slug: string): Promise<CardModel | null> {
        return this.cardsService.getCardBySlug(slug);
    }
}
