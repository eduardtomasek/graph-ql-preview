import { Injectable, Logger } from '@nestjs/common';
import { CardsBuilderProjectionsService } from '../../projections/services/cards-builder.projections.service';
import { CardsPgRepository } from '../repositories/cards.pg.repository';

@Injectable()
export class BootstrapCardsService {
    private readonly logger = new Logger(BootstrapCardsService.name);

    constructor(
        private readonly cardsBuilderProjectionsService: CardsBuilderProjectionsService,
        private readonly cardsPgRepository: CardsPgRepository,
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

        await this.cardsBuilderProjectionsService.buildProjectionCardsDataBySlugs(cardSlugs.map((card) => card.slug));
    }
}
