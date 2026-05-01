import { Controller } from '@nestjs/common';
import { BootstrapService } from '../services/bootstrap.service';

@Controller('bootstrap')
export class BootstrapController {
    constructor(private readonly bootstrapService: BootstrapService) {}
}
