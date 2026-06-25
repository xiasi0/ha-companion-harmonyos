export enum AppIconSource {
  SYSTEM = 'system',
  MATERIAL = 'material'
}

export interface AppIconSpec {
  source: AppIconSource;
  name: string;
}

export function materialIcon(name: string): AppIconSpec {
  return {
    source: AppIconSource.MATERIAL,
    name
  };
}

export function systemIcon(name: string): AppIconSpec {
  return {
    source: AppIconSource.SYSTEM,
    name
  };
}
