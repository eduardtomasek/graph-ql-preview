import { Module } from '@nestjs/common';
import { mainDbProvider } from './main-db.provider';

@Module({
    controllers: [],
    providers: [mainDbProvider],
    exports: [mainDbProvider],
})
export class MainDbModule {}
