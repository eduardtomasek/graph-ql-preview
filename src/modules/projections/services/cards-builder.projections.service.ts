import { Injectable } from '@nestjs/common';
import { CardsProjectionsBuilder } from '../builders/cards/cards.projections.builder';

@Injectable()
export class CardsBuilderProjectionsService {
    constructor(private readonly cardsProjectionsBuilder: CardsProjectionsBuilder) {}

    async buildProjectionCardsDataBySlugs(slugs: string[]) {
        await this.cardsProjectionsBuilder.buildProjectionCardsData(slugs);
    }
}
