export enum ConnectionErrorKind {
  Unreachable = 'unreachable',
  Timeout = 'timeout',
  Security = 'security',
  Authentication = 'authentication',
  Unknown = 'unknown'
}

export enum ConnectionErrorSource {
  OnboardingProbe = 'onboarding_probe'
}

export interface ConnectionError {
  kind: ConnectionErrorKind;
  source: ConnectionErrorSource;
  url: string;
  requestUrl: string;
  code: number;
  detail: string;
}
