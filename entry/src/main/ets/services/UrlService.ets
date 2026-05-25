// URL normalization and safety checks for user-entered Home Assistant endpoints.
// Keep network address validation here before URLs reach auth, dashboard, or API services.
import { UrlGuardResult } from '../models/UrlGuardResult';

export class UrlService {
  static normalizeBaseUrl(input: string): string {
    let trimmed = input.trim();
    if (trimmed.length === 0) {
      return '';
    }

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = `http://${trimmed}`;
    }

    const schemeSep = trimmed.indexOf('://');
    if (schemeSep > -1) {
      const pathIdx = trimmed.indexOf('/', schemeSep + 3);
      const qIdx = trimmed.indexOf('?', schemeSep + 3);
      const hIdx = trimmed.indexOf('#', schemeSep + 3);
      let cut = trimmed.length;
      if (pathIdx > -1 && pathIdx < cut) {
        cut = pathIdx;
      }
      if (qIdx > -1 && qIdx < cut) {
        cut = qIdx;
      }
      if (hIdx > -1 && hIdx < cut) {
        cut = hIdx;
      }
      trimmed = trimmed.slice(0, cut);
    }

    return trimmed.endsWith('/') ? trimmed.slice(0, trimmed.length - 1) : trimmed;
  }

  static parseQueryParam(url: string, key: string): string {
    const q = url.indexOf('?');
    if (q < 0 || q >= url.length - 1) {
      return '';
    }

    const query = url.slice(q + 1);
    const pairs = query.split('&');
    let i = 0;
    while (i < pairs.length) {
      const item = pairs[i];
      const eq = item.indexOf('=');
      const k = eq >= 0 ? item.slice(0, eq) : item;
      const v = eq >= 0 ? item.slice(eq + 1) : '';
      if (k === key) {
        try {
          return decodeURIComponent(v);
        } catch (_) {
          return v;
        }
      }
      i += 1;
    }

    return '';
  }

  static isHttpLikeUrl(url: string): boolean {
    return url.startsWith('http://') || url.startsWith('https://');
  }

  static endpointKey(url: string): string {
    const normalized = UrlService.normalizeBaseUrl(url).toLowerCase();
    if (normalized.startsWith('http://')) {
      return normalized.slice(7);
    }
    if (normalized.startsWith('https://')) {
      return normalized.slice(8);
    }
    return normalized;
  }

  static buildUrlWithBaseHost(baseUrl: string, currentUrl: string): string {
    const normalizedBase = UrlService.normalizeBaseUrl(baseUrl);
    if (!normalizedBase || !UrlService.isHttpLikeUrl(currentUrl)) {
      return currentUrl;
    }

    const schemeIdx = currentUrl.indexOf('://');
    if (schemeIdx < 0) {
      return normalizedBase;
    }
    const hostStart = schemeIdx + 3;
    let pathStart = currentUrl.indexOf('/', hostStart);
    if (pathStart < 0) {
      pathStart = currentUrl.length;
    }
    const tail = currentUrl.slice(pathStart);
    return `${normalizedBase}${tail}`;
  }

  static guardAndRewriteUrl(currentUrl: string, baseUrlInput: string): UrlGuardResult {
    const baseUrl = UrlService.normalizeBaseUrl(baseUrlInput);
    if (!currentUrl || !baseUrl) {
      return { intercept: false, rewrittenUrl: '' };
    }

    if (
      currentUrl.startsWith('about:') ||
      currentUrl.startsWith('data:') ||
      currentUrl.startsWith('javascript:')
    ) {
      return { intercept: false, rewrittenUrl: '' };
    }

    if (!UrlService.isHttpLikeUrl(currentUrl)) {
      return { intercept: false, rewrittenUrl: '' };
    }

    const targetKey = UrlService.endpointKey(currentUrl);
    const baseKey = UrlService.endpointKey(baseUrl);
    if (targetKey === baseKey) {
      return { intercept: false, rewrittenUrl: '' };
    }

    const rewritten = UrlService.buildUrlWithBaseHost(baseUrl, currentUrl);
    return { intercept: true, rewrittenUrl: rewritten };
  }

  static appendQueryParam(url: string, key: string, value: string): string {
    const separator = url.indexOf('?') >= 0 ? '&' : '?';
    return `${url}${separator}${encodeURIComponent(key)}=${encodeURIComponent(value)}`;
  }

  static buildDashboardUrl(baseUrl: string): string {
    return UrlService.appendQueryParam(baseUrl, 'external_auth', '1');
  }

  static urlPathOnly(url: string): string {
    if (!url) {
      return '';
    }
    let value = url;
    const hashIndex = value.indexOf('#');
    if (hashIndex >= 0) {
      value = value.slice(0, hashIndex);
    }
    const queryIndex = value.indexOf('?');
    if (queryIndex >= 0) {
      value = value.slice(0, queryIndex);
    }
    const schemeIndex = value.indexOf('://');
    if (schemeIndex >= 0) {
      const slashIndex = value.indexOf('/', schemeIndex + 3);
      value = slashIndex >= 0 ? value.slice(slashIndex) : '/';
    }
    while (value.length > 1 && value.endsWith('/')) {
      value = value.slice(0, value.length - 1);
    }
    return value.length > 0 ? value : '/';
  }

  static isDashboardHomeUrl(url: string): boolean {
    const path = UrlService.urlPathOnly(url);
    return path === '/' || path === '/lovelace' || path === '/lovelace/default_view';
  }
}
