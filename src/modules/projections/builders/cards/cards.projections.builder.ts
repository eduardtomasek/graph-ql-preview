import { Injectable } from '@nestjs/common';
import { CardsBuilderProjectionsPgRepository } from '../../repositories/cards-builder.projections.pg.repository';

@Injectable()
export class CardsProjectionsBuilder {
    constructor(private readonly cardsBuilderProjectionsPgRepository: CardsBuilderProjectionsPgRepository) {}

    async buildProjectionCardsData(slugs: string[]) {
        const cards = await this.cardsBuilderProjectionsPgRepository.findBySlugs(slugs);

        if (cards.length === 0) {
            return;
        }

        await this.cardsBuilderProjectionsPgRepository.storeCardProjections(cards);
    }
}
