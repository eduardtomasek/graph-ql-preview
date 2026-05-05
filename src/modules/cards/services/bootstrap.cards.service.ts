import { Injectable, Logger } from '@nestjs/common';
import { CardsCacheService } from '../../cache/services/cards.cache.service';
import { CardsBuilderProjectionsService } from '../../projections/services/cards-builder.projections.service';
import { ProjectionsService } from '../../projections/services/projections.service';
import { CardsMapper } from '../mappers/cards.mapper';
import { CardsPgRepository } from '../repositories/cards.pg.repository';

@Injectable()
export class BootstrapCardsService {
    private readonly logger = new Logger(BootstrapCardsService.name);

    constructor(
        private readonly cardsBuilderProjectionsService: CardsBuilderProjectionsService,
        private readonly projectionsService: ProjectionsService,
        private readonly cardsPgRepository: CardsPgRepository,
        private readonly cardsCacheService: CardsCacheService,
        private readonly cardsMapper: CardsMapper,
    ) {}

    onModuleInit() {
        this.logger.debug('Starting bootstrap of card projections...');
        this.bootstrapCards()
            .then(() => {
                this.logger.debug('Finished bootstrap of card projections.');
            })
            .catch((error) => {
                this.logger.error('Error during bootstrap of card projections:', error);
            });
    }

    async bootstrapCards() {
        const cardSlugs = await this.cardsPgRepository.findAllCardsSlugs();

        const slugs = cardSlugs.map((card) => card.slug);

        await this.cardsBuilderProjectionsService.buildProjectionCardsDataBySlugs(slugs);

        const projectionsCards = await this.projectionsService.findBySlugs(slugs);

        const cardsDataToCache = projectionsCards.map((projectionCard) =>
            this.cardsMapper.projectionCardRowToCardModel(projectionCard),
        );

        await this.cardsCacheService.cacheCardsBySlugs(cardsDataToCache);
    }
}
