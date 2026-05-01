import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
    /**
     * Generates a simple SVG favicon with a colored circle and letter
     * @param letter The capital letter to display in the center
     * @param backgroundColor The background color of the circle (hex code)
     * @param textColor The color of the letter (hex code)
     * @returns SVG string
     */
    generateFavicon(letter: string = 'G', backgroundColor: string = '#A801CD', textColor: string = '#FFFFFF'): string {
        // Use first letter and ensure it's uppercase
        const displayLetter = letter.charAt(0).toUpperCase();

        // Create SVG favicon
        const svg = `<?xml version="1.0" encoding="UTF-8" standalone="no"?>
            <svg width="32" height="32" viewBox="0 0 32 32" xmlns="http://www.w3.org/2000/svg">
                <circle cx="16" cy="16" r="16" fill="${backgroundColor}" />
                <text x="16" y="16" font-family="Arial, sans-serif" font-size="16" font-weight="bold" fill="${textColor}" text-anchor="middle" dy=".35em">${displayLetter}</text>
            </svg>
        `;

        return svg;
    }
}
