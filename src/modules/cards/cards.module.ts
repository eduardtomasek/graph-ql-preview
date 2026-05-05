import { Module } from '@nestjs/common';
import { MainDbModule } from '../../infrastructure/databases/main-db/main-db.module';
import { CacheModule } from '../cache/cache.module';
import { ProjectionsModule } from '../projections/projections.module';
import { CardsMapper } from './mappers/cards.mapper';
import { CardsPgRepository } from './repositories/cards.pg.repository';
import { CardsResolver } from './resolvers/cards.resolver';
import { BootstrapCardsService } from './services/bootstrap.cards.service';
import { CardsService } from './services/cards.service';

@Module({
    imports: [MainDbModule, ProjectionsModule, CacheModule],
    controllers: [],
    providers: [
        // services
        CardsService,
        BootstrapCardsService,

        // repositories
        CardsPgRepository,

        // resolvers
        CardsResolver,

        // mappers
        CardsMapper,
    ],
})
export class CardsModule {}
