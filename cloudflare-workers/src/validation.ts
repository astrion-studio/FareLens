/**
 * Shared validation schemas for FareLens Cloudflare Workers API
 *
 * Centralized validation patterns to ensure consistency across all endpoints.
 * All IATA codes, destinations, and other validated fields use these schemas.
 */

import { z } from 'zod';

/**
 * IATA airport code pattern
 * Format: Exactly 3 uppercase letters (e.g., LAX, JFK, ORD)
 * Does NOT match "ANY" - origin must always be a specific airport
 */
export const IATA_CODE_PATTERN = /^[A-Z]{3}$/;

/**
 * Destination code pattern
 * Format: Either 3 uppercase letters (IATA code) OR the literal string "ANY"
 * Examples that match: "LAX", "JFK", "ANY"
 * Examples that DON'T match: "ANYZZZ", "any", "LA"
 */
export const DESTINATION_PATTERN = /^([A-Z]{3}|ANY)$/;

/**
 * Zod schema for origin validation
 * Origin must be a valid IATA code - never "ANY"
 */
export const originValidation = z
  .string()
  .regex(IATA_CODE_PATTERN, 'Origin must be 3-letter IATA code (e.g., LAX, JFK)');

/**
 * Zod schema for destination validation
 * Destination can be a valid IATA code OR "ANY" (for flexible destination searches)
 */
export const destinationValidation = z
  .string()
  .regex(DESTINATION_PATTERN, 'Destination must be 3-letter IATA code or ANY');

/**
 * Zod schema for UUID validation
 * Used for user IDs, watchlist IDs, etc.
 */
export const uuidValidation = z
  .string()
  .uuid('Must be valid UUID format');

/**
 * Zod schema for price validation
 * Must be a positive number
 */
export const priceValidation = z
  .number()
  .positive('Price must be positive');

/**
 * Zod schema for date-time validation
 * Must be valid ISO 8601 datetime string
 */
export const datetimeValidation = z
  .string()
  .datetime('Must be valid ISO 8601 datetime');
