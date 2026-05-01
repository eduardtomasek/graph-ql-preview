import { Module } from '@nestjs/common';
import { MainDbModule } from '../../infrastructure/databases/main-db/main-db.module';
import { BootstrapController } from './controllers/bootstrap.controller';
import { BootstrapPgRepository } from './repositories/bootstrap.pg.repository';
import { BootstrapService } from './services/bootstrap.service';

@Module({
    imports: [MainDbModule],
    controllers: [BootstrapController],
    providers: [
        // services
        BootstrapService,

        // repositories
        BootstrapPgRepository,
    ],
})
export class BootstrapModule {}
