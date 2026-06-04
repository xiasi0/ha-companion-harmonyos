// Access-token repository for the active Home Assistant server.
// It bridges server selection with secure token storage and registration identity.
import common from '@ohos.app.ability.common';
import { AuthService } from './AuthService';
import { ServerManager } from './ServerManager';
import { StoredServerInfo, StorageService } from './StorageService';

export interface ServerAuthSession {
  serverInstanceId: string;
  baseUrl: string;
  accessToken: string;
  refreshToken: string;
}

class ServerAuthSessionPayload implements ServerAuthSession {
  serverInstanceId: string = '';
  baseUrl: string = '';
  accessToken: string = '';
  refreshToken: string = '';
}

export class ServerAuthRepository {
  private static readonly REFRESH_SKEW_MS: number = 2 * 60 * 1000;

  static loadSync(context: common.Context, serverInstanceId: string): ServerAuthSession {
    const id = serverInstanceId.trim();
    if (id.length === 0) {
      return new ServerAuthSessionPayload();
    }
    const info = ServerManager.getServerInfoSync(context, id);
    return ServerAuthRepository.session(id, info);
  }

  static async load(context: common.Context, serverInstanceId: string): Promise<ServerAuthSession> {
    const id = serverInstanceId.trim();
    if (id.length === 0) {
      return new ServerAuthSessionPayload();
    }
    const info = await ServerManager.getServerInfo(context, id);
    return ServerAuthRepository.session(id, info);
  }

  static async loadFresh(context: common.Context, serverInstanceId: string): Promise<ServerAuthSession> {
    return ServerAuthRepository.loadFreshWithBaseUrl(context, serverInstanceId, '');
  }

  static async loadFreshWithBaseUrl(
    context: common.Context,
    serverInstanceId: string,
    refreshBaseUrl: string
  ): Promise<ServerAuthSession> {
    const id = serverInstanceId.trim();
    if (id.length === 0) {
      return new ServerAuthSessionPayload();
    }
    const info = await ServerManager.getServerInfo(context, id);
    const session = ServerAuthRepository.session(id, info);
    if (session.accessToken.length === 0) {
      if (session.refreshToken.length > 0) {
        const refreshed = await ServerAuthRepository.refreshWithBaseUrl(context, id, refreshBaseUrl);
        return refreshed.accessToken.length > 0 ? refreshed : session;
      }
      return session;
    }
    if (!ServerAuthRepository.shouldRefresh(info)) {
      return session;
    }
    const refreshed = await ServerAuthRepository.refreshWithBaseUrl(context, id, refreshBaseUrl);
    if (refreshed.accessToken.length === 0) {
      return session;
    }
    if (refreshBaseUrl.trim().length > 0) {
      refreshed.baseUrl = refreshBaseUrl.trim();
    }
    return refreshed;
  }

  static async refresh(context: common.Context, serverInstanceId: string): Promise<ServerAuthSession> {
    return ServerAuthRepository.refreshWithBaseUrl(context, serverInstanceId, '');
  }

  static async refreshWithBaseUrl(
    context: common.Context,
    serverInstanceId: string,
    refreshBaseUrl: string
  ): Promise<ServerAuthSession> {
    const current = await ServerAuthRepository.load(context, serverInstanceId);
    if (current.baseUrl.length === 0 || current.refreshToken.length === 0) {
      return new ServerAuthSessionPayload();
    }
    const baseUrl = refreshBaseUrl.trim().length > 0 ? refreshBaseUrl.trim() : current.baseUrl;
    const result = await AuthService.refreshAccessToken(baseUrl, current.refreshToken);
    if (!result.success || result.accessToken.trim().length === 0) {
      return new ServerAuthSessionPayload();
    }
    const nextRefreshToken = result.refreshToken.trim().length > 0 ? result.refreshToken.trim() : current.refreshToken;
    const currentInfo = await ServerManager.getServerInfo(context, current.serverInstanceId);
    const nextInfo = StorageService.applyRefresh(
      currentInfo,
      result.accessToken.trim(),
      nextRefreshToken,
      StorageService.accessTokenExpiresAt(result.expiresIn)
    );
    await ServerManager.updateServerInfo(context, current.serverInstanceId, nextInfo);
    const nextSession = ServerAuthRepository.session(current.serverInstanceId, nextInfo);
    nextSession.baseUrl = baseUrl;
    return nextSession;
  }

  private static shouldRefresh(info: StoredServerInfo): boolean {
    if (info.refreshToken.trim().length === 0) {
      return false;
    }
    return info.accessTokenExpiresAt <= Date.now() + ServerAuthRepository.REFRESH_SKEW_MS;
  }

  private static session(serverInstanceId: string, info: StoredServerInfo): ServerAuthSession {
    if (!StorageService.hasCredentials(info)) {
      return new ServerAuthSessionPayload();
    }
    const session = new ServerAuthSessionPayload();
    session.serverInstanceId = serverInstanceId.trim();
    session.baseUrl = info.baseUrl.trim();
    session.accessToken = info.accessToken.trim();
    session.refreshToken = info.refreshToken.trim();
    return session;
  }
}
