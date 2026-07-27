import { HaConfigInfo } from '../models/HaConfigInfo';

export interface HaConfigFetchResult {
  responseCode: number;
  config: HaConfigInfo;
  failureSummary: string;
}

export interface HaMobileAppRegistrationRequest {
  appId: string;
  appName: string;
  appVersion: string;
  deviceName: string;
  manufacturer: string;
  model: string;
  osName: string;
  osVersion: string;
  supportsEncryption: boolean;
  appData: Record<string, string | number | boolean>;
  deviceId: string;
}

export interface HaMobileAppRegistrationInfo {
  webhookId: string;
  webhookSecret: string;
  cloudhookUrl: string;
  remoteUiUrl: string;
}

export interface HaMobileAppRegistrationResult {
  responseCode: number;
  registration: HaMobileAppRegistrationInfo;
  failureSummary: string;
}

export interface HaConversationAgent {
  id: string;
  name: string;
}

export interface HaConversationAgentsResult {
  responseCode: number;
  agents: HaConversationAgent[];
  failureSummary: string;
}

export interface HaAssistPipelineRunResult {
  success: boolean;
  text: string;
  conversationId: string;
  failureSummary: string;
}

export interface HaLightEntity {
  entityId: string;
  name: string;
  areaName: string;
  state: string;
}

export interface HaBindableEntity {
  entityId: string;
  name: string;
  areaName: string;
  state: string;
}

export interface HaEntityCatalogItem {
  entityId: string;
  domain: string;
  name: string;
  areaId: string;
  areaName: string;
  deviceId: string;
  deviceName: string;
  entityCategory: string;
  deviceClass: string;
  unitOfMeasurement: string;
  icon: string;
  state: string;
}

export interface HaAreaRegistryItem {
  areaId: string;
  name: string;
}

export interface HaDeviceRegistryItem {
  deviceId: string;
  areaId: string;
  name: string;
}

export interface HaEntityRegistryItem {
  entityId: string;
  areaId: string;
  deviceId: string;
  entityCategory: string;
}

export interface HaRegistryCatalog {
  areas: HaAreaRegistryItem[];
  devices: HaDeviceRegistryItem[];
  entities: HaEntityRegistryItem[];
}

export interface HaEntityCatalogResult {
  responseCode: number;
  entities: HaEntityCatalogItem[];
  failureSummary: string;
}

export interface HaLightEntitiesResult {
  responseCode: number;
  entities: HaLightEntity[];
  failureSummary: string;
}

export interface HaMediaPlayerEntity {
  entityId: string;
  name: string;
  areaName: string;
  state: string;
  mediaTitle: string;
  mediaArtist: string;
  appName: string;
  entityPicture: string;
}

export interface HaCameraEntity {
  entityId: string;
  name: string;
  areaName: string;
  state: string;
  entityPicture: string;
}

export interface HaMediaPlayerEntitiesResult {
  responseCode: number;
  entities: HaMediaPlayerEntity[];
  failureSummary: string;
}

export interface HaLightActionResult {
  success: boolean;
  responseCode: number;
  state: string;
  failureSummary: string;
}
