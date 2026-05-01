import { Controller, Get, Header } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
    constructor(private readonly appService: AppService) {}

    @Get('/favicon.ico')
    @Header('Content-Type', 'image/svg+xml')
    @Header('Cache-Control', 'public, max-age=86400')
    getFavicon(): string {
        return this.appService.generateFavicon('G', '#99005eff');
    }

    @Get('health-check')
    getHealth(): string {
        return 'OK';
    }
}
