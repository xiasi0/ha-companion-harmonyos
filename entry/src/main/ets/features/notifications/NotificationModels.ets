export interface NotificationAction {
  key: string;
  title: string;
  uri: string;
  behavior: string;
  authenticationRequired: boolean;
  data: Record<string, string>;
}

export interface LocalNotificationPayload {
  id?: number;
  dedupeKey?: string;
  serverInstanceId?: string;
  title: string;
  text: string;
  additionalText?: string;
  source?: string;
  data?: Record<string, string>;
  actions?: NotificationAction[];
}
