// Normalizes home-network settings used for internal URL and local-first decisions.
// Platform Wi-Fi lookup is kept outside so this service stays deterministic.
export interface WirelessSnapshot {
  connected: boolean;
  ssid: string;
  isHidden: boolean;
  rssi: number;
  signalLevel: number;
  frequency: number;
  linkSpeed: number;
  ipAddress: string;
}

export interface HomeNetworkSettings {
  wifiSsids: string[];
  prioritizeInternal: boolean;
}

export interface HomeNetworkEvaluation {
  isOnHomeWifi: boolean;
  isOnHomeNetwork: boolean;
  matchedSsid: string;
  currentSsid: string;
  reason: string;
}

export interface FrontendUrlResolutionInput {
  externalUrl: string;
  internalUrl: string;
  secureConnectionChoice: string;
  currentUrl: string;
  settings: HomeNetworkSettings;
  snapshot: WirelessSnapshot;
}

export interface BaseUrlResolutionInput {
  externalUrl: string;
  internalUrl: string;
  secureConnectionChoice: string;
  settings: HomeNetworkSettings;
  snapshot: WirelessSnapshot;
}

export interface FrontendUrlResolution {
  kind: string;
  url: string;
  missingHomeSetup: boolean;
  reason: string;
}

export class HomeNetworkService {
  static emptyWirelessSnapshot(): WirelessSnapshot {
    return {
      connected: false,
      ssid: '',
      isHidden: false,
      rssi: 0,
      signalLevel: 0,
      frequency: 0,
      linkSpeed: 0,
      ipAddress: ''
    };
  }

  static normalizeSsid(value: string): string {
    let normalized = value.trim();
    if (normalized.length >= 2 && normalized.startsWith('"') && normalized.endsWith('"')) {
      normalized = normalized.substring(1, normalized.length - 1).trim();
    }
    return normalized;
  }

  static normalizeSsidList(values: string[]): string[] {
    const result: string[] = [];
    for (let i = 0; i < values.length; i++) {
      const normalized = HomeNetworkService.normalizeSsid(values[i]);
      if (normalized.length === 0 || HomeNetworkService.containsText(result, normalized)) {
        continue;
      }
      result.push(normalized);
    }
    return result;
  }

  static settingsFromStored(
    wifiSsids: string[],
    legacyHomeNetworkName: string,
    prioritizeInternal: boolean
  ): HomeNetworkSettings {
    let normalizedSsids = HomeNetworkService.normalizeSsidList(wifiSsids);
    if (normalizedSsids.length === 0) {
      normalizedSsids = HomeNetworkService.normalizeSsidList([legacyHomeNetworkName]);
    }
    return {
      wifiSsids: normalizedSsids,
      prioritizeInternal: prioritizeInternal
    };
  }

  static evaluate(snapshot: WirelessSnapshot, settings: HomeNetworkSettings): HomeNetworkEvaluation {
    const currentSsid = HomeNetworkService.normalizeSsid(snapshot.ssid);
    if (!snapshot.connected) {
      return HomeNetworkService.evaluation(false, '', currentSsid, 'wifi_disconnected');
    }
    if (currentSsid.length === 0) {
      return HomeNetworkService.evaluation(false, '', currentSsid, 'wifi_unknown');
    }
    const homeSsids = HomeNetworkService.normalizeSsidList(settings.wifiSsids);
    for (let i = 0; i < homeSsids.length; i++) {
      if (homeSsids[i] === currentSsid) {
        return HomeNetworkService.evaluation(true, homeSsids[i], currentSsid, 'wifi_ssid');
      }
    }
    return HomeNetworkService.evaluation(false, '', currentSsid, 'wifi_not_matched');
  }

  static hasHomeSetup(settings: HomeNetworkSettings): boolean {
    return HomeNetworkService.normalizeSsidList(settings.wifiSsids).length > 0;
  }

  static resolveFrontendUrl(input: FrontendUrlResolutionInput): FrontendUrlResolution {
    const baseResolution = HomeNetworkService.resolveBaseUrl({
      externalUrl: input.externalUrl,
      internalUrl: input.internalUrl,
      secureConnectionChoice: input.secureConnectionChoice,
      settings: input.settings,
      snapshot: input.snapshot
    });
    if (baseResolution.kind !== 'success') {
      return baseResolution;
    }
    return HomeNetworkService.resolution(
      'success',
      HomeNetworkService.buildDashboardUrl(baseResolution.url, input.currentUrl),
      baseResolution.missingHomeSetup,
      'ok'
    );
  }

  static resolveBaseUrl(input: BaseUrlResolutionInput): FrontendUrlResolution {
    const internalUrl = HomeNetworkService.normalizeBaseUrl(input.internalUrl);
    const externalUrl = HomeNetworkService.normalizeBaseUrl(input.externalUrl);
    const hasHomeSetup = HomeNetworkService.hasHomeSetup(input.settings);
    const evaluation = HomeNetworkService.evaluate(input.snapshot, input.settings);
    const isOnHomeNetwork = evaluation.isOnHomeNetwork;
    const blockReason = hasHomeSetup ? evaluation.reason : 'missing_home_setup';
    const secureChoice = input.secureConnectionChoice.trim();
    const allowsInsecure = secureChoice !== 'most';

    let baseUrl = '';
    if (isOnHomeNetwork && internalUrl.length > 0) {
      baseUrl = internalUrl;
    } else if (externalUrl.length > 0) {
      baseUrl = externalUrl;
    } else if (internalUrl.length > 0 && allowsInsecure) {
      baseUrl = internalUrl;
    } else if (internalUrl.startsWith('https://')) {
      baseUrl = internalUrl;
    }

    if (baseUrl.length === 0) {
      return HomeNetworkService.resolution('no_url', '', !hasHomeSetup, 'no_url');
    }

    if (!allowsInsecure && baseUrl.startsWith('http://') && !isOnHomeNetwork) {
      return HomeNetworkService.resolution('insecure_blocked', '', !hasHomeSetup, blockReason);
    }

    return HomeNetworkService.resolution(
      'success',
      baseUrl,
      !hasHomeSetup,
      'ok'
    );
  }

  private static normalizeBaseUrl(input: string): string {
    let trimmed = input.trim();
    if (trimmed.length === 0) {
      return '';
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = `http://${trimmed}`;
    }
    const schemeIndex = trimmed.indexOf('://');
    if (schemeIndex >= 0) {
      const start = schemeIndex + 3;
      let cut = trimmed.length;
      const pathIndex = trimmed.indexOf('/', start);
      const queryIndex = trimmed.indexOf('?', start);
      const fragmentIndex = trimmed.indexOf('#', start);
      if (pathIndex >= 0 && pathIndex < cut) {
        cut = pathIndex;
      }
      if (queryIndex >= 0 && queryIndex < cut) {
        cut = queryIndex;
      }
      if (fragmentIndex >= 0 && fragmentIndex < cut) {
        cut = fragmentIndex;
      }
      trimmed = trimmed.slice(0, cut);
    }
    return trimmed.endsWith('/') ? trimmed.slice(0, trimmed.length - 1) : trimmed;
  }

  private static buildDashboardUrl(baseUrl: string, currentUrl: string): string {
    const tail = HomeNetworkService.currentPathQueryFragment(currentUrl);
    const normalizedTail = HomeNetworkService.isDashboardHomeTail(tail) ? '' : tail;
    let nextUrl = `${baseUrl}${normalizedTail}`;
    if (nextUrl.indexOf('external_auth=') < 0) {
      nextUrl += nextUrl.indexOf('?') >= 0 ? '&external_auth=1' : '?external_auth=1';
    }
    return nextUrl;
  }

  private static isDashboardHomeTail(tail: string): boolean {
    if (tail.length === 0) {
      return true;
    }
    let path = tail;
    const hashIndex = path.indexOf('#');
    if (hashIndex >= 0) {
      path = path.slice(0, hashIndex);
    }
    const queryIndex = path.indexOf('?');
    if (queryIndex >= 0) {
      path = path.slice(0, queryIndex);
    }
    while (path.length > 1 && path.endsWith('/')) {
      path = path.slice(0, path.length - 1);
    }
    return path === '/' || path === '/lovelace' || path === '/lovelace/default_view';
  }

  private static currentPathQueryFragment(url: string): string {
    const value = url.trim();
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return '';
    }
    const schemeIndex = value.indexOf('://');
    const pathIndex = value.indexOf('/', schemeIndex + 3);
    if (pathIndex < 0) {
      return '';
    }
    return value.slice(pathIndex);
  }

  private static resolution(
    kind: string,
    url: string,
    missingHomeSetup: boolean,
    reason: string
  ): FrontendUrlResolution {
    return {
      kind: kind,
      url: url,
      missingHomeSetup: missingHomeSetup,
      reason: reason
    };
  }

  private static evaluation(
    matched: boolean,
    matchedSsid: string,
    currentSsid: string,
    reason: string
  ): HomeNetworkEvaluation {
    return {
      isOnHomeWifi: matched,
      isOnHomeNetwork: matched,
      matchedSsid: matchedSsid,
      currentSsid: currentSsid,
      reason: reason
    };
  }

  private static containsText(values: string[], target: string): boolean {
    for (let i = 0; i < values.length; i++) {
      if (values[i] === target) {
        return true;
      }
    }
    return false;
  }
}
