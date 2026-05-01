import { Injectable, InternalServerErrorException, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as fs from 'fs';
import * as path from 'path';
import { BootstrapPgRepository } from '../repositories/bootstrap.pg.repository';

@Injectable()
export class BootstrapService implements OnModuleInit {
    private readonly logger = new Logger(BootstrapService.name);

    constructor(
        private readonly bootstrapPgRepository: BootstrapPgRepository,
        private readonly configService: ConfigService,
    ) {}

    async onModuleInit(): Promise<void> {
        if (this.configService.get('BOOTSTRAP_DB') !== 'true') {
            this.logger.log('BOOTSTRAP_DB is not set to true, skipping database bootstrap.');
            return;
        }

        await this.bootstrapDatabase();
    }

    async bootstrapDatabase(): Promise<void> {
        const schemaPath = path.join(__dirname, '../../../assets/bootstrap.sql');

        let sql: string;

        try {
            sql = fs.readFileSync(schemaPath, 'utf8');
        } catch (err) {
            const message = err instanceof Error ? err.message : String(err);
            this.logger.error(`Failed to read bootstrap.sql at ${schemaPath}: ${message}`);
            throw new InternalServerErrorException('Database schema file could not be loaded.');
        }

        if (!sql.trim()) {
            throw new InternalServerErrorException('Database schema file is empty.');
        }

        await this.bootstrapPgRepository.bootstrapDatabase(sql);
    }
}
