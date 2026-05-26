// Home Assistant discovery client for local network onboarding.
// It fetches and normalizes discovered server candidates before UI presentation.
import common from '@ohos.app.ability.common';
import { HaServerItem } from '../models/HaServerItem';
import { Localization } from '../shared/i18n/Localization';
import { NetworkHttpMethod, NetworkMdnsLocalServiceInfo, NetworkService } from './NetworkService';
import { UrlService } from './UrlService';

export interface HaServerProbeResult {
  reachable: boolean;
  baseUrl: string;
  responseCode: number;
  detail: string;
}

export class DiscoveryService {
  static buildDiscoveryCandidates(baseUrl: string, manualAddress: string): string[] {
    const candidates: string[] = [];
    DiscoveryService.pushCandidate(candidates, baseUrl);
    DiscoveryService.pushCandidate(candidates, manualAddress);
    return candidates;
  }

  static async discoverByMdns(appContext: common.Context, timeoutMs: number = 4500): Promise<HaServerItem[]> {
    const discovery = NetworkService.createMdnsDiscoveryService(appContext, '_home-assistant._tcp');
    const foundServices: NetworkMdnsLocalServiceInfo[] = [];
    const onFound = (serviceInfo: NetworkMdnsLocalServiceInfo): void => {
      foundServices.push(serviceInfo);
    };

    discovery.on('serviceFound', onFound);
    discovery.startSearchingMDNS();

    await new Promise<void>((resolve: () => void) => {
      setTimeout((): void => {
        resolve();
      }, timeoutMs);
    });

    discovery.stopSearchingMDNS();
    discovery.off('serviceFound', onFound);

    const servers: HaServerItem[] = [];
    let i = 0;
    while (i < foundServices.length) {
      const svc = foundServices[i];
      let resolvedSvc = svc;
      try {
        const resolved = await NetworkService.resolveMdnsLocalService(appContext, svc);
        resolvedSvc = resolved;
      } catch (_) {
        // Keep using raw discovery result if resolve fails.
      }

      const hostObj = resolvedSvc.host ? resolvedSvc.host : svc.host;
      const host = hostObj && typeof hostObj.address === 'string' ? hostObj.address : '';
      const port = resolvedSvc.port ? resolvedSvc.port : (svc.port ? svc.port : 8123);
      const serviceName = resolvedSvc.serviceName ? resolvedSvc.serviceName : (svc.serviceName ? svc.serviceName : 'Home Assistant');

      if (host) {
        const url = `http://${host}:${port}`;
        servers.push(DiscoveryService.createServerItem(url, 'mDNS', serviceName, Localization.t('discovery_status_default')));
      }
      i += 1;
    }
    return servers;
  }

  static async probeHaServer(baseUrl: string): Promise<boolean> {
    return (await DiscoveryService.probeHaServerResult(baseUrl)).reachable;
  }

  static async probeHaServerResult(baseUrl: string): Promise<HaServerProbeResult> {
    const attempts: string[] = [baseUrl];
    if (baseUrl.startsWith('http://')) {
      attempts.push(`https://${baseUrl.slice(7)}`);
    } else if (baseUrl.startsWith('https://')) {
      attempts.push(`http://${baseUrl.slice(8)}`);
    }

    let lastFailure: HaServerProbeResult = {
      reachable: false,
      baseUrl,
      responseCode: 0,
      detail: Localization.t('connection_error_unknown_detail')
    };

    let i = 0;
    while (i < attempts.length) {
      const target = attempts[i];
      try {
        const discoveryResp = await NetworkService.requestText(`${target}/api/discovery_info`, {
          method: NetworkHttpMethod.GET,
          connectTimeout: 2500,
          readTimeout: 2500
        });
        if (discoveryResp.responseCode >= 200 && discoveryResp.responseCode < 300) {
          const discoveryBody = discoveryResp.body.toLowerCase();
          if (discoveryBody.indexOf('home assistant') >= 0 || discoveryBody.indexOf('homeassistant') >= 0) {
            return {
              reachable: true,
              baseUrl: target,
              responseCode: discoveryResp.responseCode,
              detail: 'Home Assistant discovery endpoint is reachable'
            };
          }
        }
        lastFailure = DiscoveryService.failureFromResponse(target, discoveryResp.responseCode, `${target}/api/discovery_info`);

        const manifestResp = await NetworkService.requestText(`${target}/manifest.json`, {
          method: NetworkHttpMethod.GET,
          connectTimeout: 2500,
          readTimeout: 2500
        });
        if (manifestResp.responseCode >= 200 && manifestResp.responseCode < 300) {
          const body = manifestResp.body;
          const lowered = body.toLowerCase();
          if (lowered.indexOf('home assistant') >= 0 || lowered.indexOf('homeassistant') >= 0) {
            return {
              reachable: true,
              baseUrl: target,
              responseCode: manifestResp.responseCode,
              detail: 'Home Assistant manifest is reachable'
            };
          }
        }
        lastFailure = DiscoveryService.failureFromResponse(target, manifestResp.responseCode, `${target}/manifest.json`);
      } catch (error) {
        const detail = NetworkService.errorText(error, Localization.t('connection_error_unknown_detail'));
        lastFailure = {
          reachable: false,
          baseUrl: target,
          responseCode: DiscoveryService.errorCodeFromDetail(detail),
          detail
        };
      }
      i += 1;
    }
    return lastFailure;
  }

  static createServerItem(
    url: string,
    source: string,
    name: string = 'Home Assistant',
    status: string = Localization.t('discovery_status_default')
  ): HaServerItem {
    return {
      name,
      url,
      key: UrlService.endpointKey(url),
      source,
      status
    };
  }

  private static pushCandidate(candidates: string[], raw: string): void {
    const trimmed = raw.trim();
    if (!trimmed) {
      return;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      const normalized = UrlService.normalizeBaseUrl(trimmed);
      if (normalized) {
        DiscoveryService.appendUnique(candidates, normalized);
      }
      return;
    }
    const httpCandidate = UrlService.normalizeBaseUrl(`http://${trimmed}`);
    if (httpCandidate) {
      DiscoveryService.appendUnique(candidates, httpCandidate);
    }
  }

  private static appendUnique(candidates: string[], normalized: string): void {
    let exists = false;
    let i = 0;
    while (i < candidates.length) {
      if (candidates[i] === normalized) {
        exists = true;
        break;
      }
      i += 1;
    }
    if (!exists) {
      candidates.push(normalized);
    }
  }

  private static failureFromResponse(baseUrl: string, responseCode: number, url: string): HaServerProbeResult {
    return {
      reachable: false,
      baseUrl,
      responseCode,
      detail: `Unexpected response from ${url}`
    };
  }

  private static errorCodeFromDetail(detail: string): number {
    const lowered = detail.toLowerCase();
    if (lowered.indexOf('timeout') >= 0 || lowered.indexOf('timed out') >= 0) {
      return -7;
    }
    return -2;
  }

}
