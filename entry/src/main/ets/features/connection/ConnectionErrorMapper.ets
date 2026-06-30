import { HaServerProbeResult } from '../../services/DiscoveryService';
import { ConnectionError, ConnectionErrorKind, ConnectionErrorSource } from './ConnectionErrorModels';

export class ConnectionErrorMapper {
  static fromProbeResult(url: string, result: HaServerProbeResult): ConnectionError {
    return ConnectionErrorMapper.create(
      url,
      result.baseUrl,
      result.responseCode,
      result.detail,
      ConnectionErrorSource.OnboardingProbe
    );
  }

  private static create(
    url: string,
    requestUrl: string,
    code: number,
    detail: string,
    source: ConnectionErrorSource
  ): ConnectionError {
    const displayDetail = detail.trim();
    return {
      kind: ConnectionErrorMapper.classify(code, displayDetail),
      source,
      url: ConnectionErrorMapper.sanitizeText(url),
      requestUrl: ConnectionErrorMapper.sanitizeText(requestUrl),
      code,
      detail: ConnectionErrorMapper.sanitizeText(displayDetail)
    };
  }

  private static classify(code: number, detail: string): ConnectionErrorKind {
    const lowered = detail.toLowerCase();
    if (lowered.indexOf('timeout') >= 0 || lowered.indexOf('timed out') >= 0 || code === -7) {
      return ConnectionErrorKind.Timeout;
    }
    if (
      lowered.indexOf('certificate') >= 0 ||
      lowered.indexOf('cert') >= 0 ||
      lowered.indexOf('tls') >= 0 ||
      lowered.indexOf('ssl') >= 0
    ) {
      return ConnectionErrorKind.Security;
    }
    if (
      lowered.indexOf('auth') >= 0 ||
      lowered.indexOf('unauthorized') >= 0 ||
      lowered.indexOf('forbidden') >= 0 ||
      code === 401 ||
      code === 403
    ) {
      return ConnectionErrorKind.Authentication;
    }
    if (
      lowered.indexOf('dns') >= 0 ||
      lowered.indexOf('connect') >= 0 ||
      lowered.indexOf('refused') >= 0 ||
      lowered.indexOf('unreachable') >= 0 ||
      lowered.indexOf('host') >= 0 ||
      lowered.indexOf('network') >= 0 ||
      lowered.indexOf('no route') >= 0 ||
      code < 0
    ) {
      return ConnectionErrorKind.Unreachable;
    }
    return ConnectionErrorKind.Unknown;
  }

  private static sanitizeText(value: string): string {
    return value
      .replace(/(access_token|refresh_token|token|auth|code|client_secret)=([^&\s]+)/ig, '$1=<redacted>')
      .replace(/Bearer\s+[A-Za-z0-9._~+/=-]+/ig, 'Bearer <redacted>');
  }
}
