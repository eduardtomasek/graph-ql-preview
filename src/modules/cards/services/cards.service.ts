import { Injectable, Logger } from '@nestjs/common';
import { ProjectionsService } from '../../projections/services/projections.service';
import { CardsMapper } from '../mappers/cards.mapper';
import { CardModel } from '../models/card.model';
import { CardsPgRepository } from '../repositories/cards.pg.repository';

@Injectable()
export class CardsService {
    private readonly logger = new Logger(CardsService.name);

    constructor(
        private readonly cardsPgRepository: CardsPgRepository,
        private readonly cardsMapper: CardsMapper,
        private readonly projectionsService: ProjectionsService,
    ) {}

    async getCardBySlug(slug: string): Promise<CardModel | null> {
        const projectionCard = await this.projectionsService.findBySlug(slug);

        if (projectionCard) {
            this.logger.debug(`Card with slug "${slug}" found in projections, returning projected card data.`);
            return this.cardsMapper.projectionCardRowToCardModel(projectionCard);
        }

        const cardRow = await this.cardsPgRepository.findCardBySlug(slug);

        if (!cardRow) {
            return null;
        }

        this.logger.debug(`Card with slug "${slug}" found in main database, returning card data.`);
        return this.cardsMapper.cardRowToCardModel(cardRow);
    }
}
