import common from '@ohos.app.ability.common';
import { tag } from '@kit.ConnectivityKit';
import { util } from '@kit.ArkTS';
import { HaConnectionPolicyService } from '../../services/HaConnectionPolicyService';
import { NetworkHttpMethod, NetworkService } from '../../services/NetworkService';
import { ManagedServer, ServerManager } from '../../services/ServerManager';
import { Localization } from '../../shared/i18n/Localization';

const APPLICATION_BUNDLE_NAME: string = 'io.homeassistant.companion';
const TAG_RECORD_DOMAIN: string = 'io.homeassistant.companion';
const TAG_RECORD_TYPE: string = 'tag';
const TAG_RECORD_TNF: number = 0x04;

interface ScanTagWebhookData {
  tag_id: string;
}

interface ScanTagWebhookBody {
  type: string;
  data: ScanTagWebhookData;
}

export class NfcTagService {
  static isSupported(): boolean {
    try {
      return canIUse('SystemCapability.Communication.NFC.Tag');
    } catch (_) {
      return false;
    }
  }

  static newTagId(): string {
    try {
      if (canIUse('SystemCapability.Utils.Lang')) {
        return util.generateRandomUUID(false);
      }
    } catch (_) {
    }
    return NfcTagService.fallbackTagId();
  }

  static async readTagId(tagInfo: tag.TagInfo): Promise<string> {
    if (!NfcTagService.isSupported()) {
      throw new Error('This device does not support NFC');
    }
    if (!NfcTagService.hasTechnology(tagInfo, tag.NDEF)) {
      throw new Error('NFC tag does not contain NDEF data');
    }
    const ndefTag = tag.getNdef(tagInfo);
    if (!ndefTag.isConnected()) {
      ndefTag.connect();
    }
    const message = await ndefTag.readNdef();
    const records = message.getNdefRecords();
    for (let i = 0; i < records.length; i++) {
      const tagId = NfcTagService.tagIdFromRecord(records[i]);
      if (tagId.length > 0) {
        return tagId;
      }
    }
    throw new Error(Localization.t('nfc_not_harmony_tag'));
  }

  static async writeTag(tagInfo: tag.TagInfo, tagId: string): Promise<void> {
    if (!NfcTagService.isSupported()) {
      throw new Error('This device does not support NFC');
    }
    const applicationRecord = tag.ndef.makeApplicationRecord(APPLICATION_BUNDLE_NAME);
    const tagRecord = tag.ndef.makeExternalRecord(
      TAG_RECORD_DOMAIN,
      TAG_RECORD_TYPE,
      NfcTagService.toBytes(tagId.trim())
    );
    const message = tag.ndef.createNdefMessage([applicationRecord, tagRecord]);
    if (NfcTagService.hasTechnology(tagInfo, tag.NDEF)) {
      const ndefTag = tag.getNdef(tagInfo);
      if (!ndefTag.isConnected()) {
        ndefTag.connect();
      }
      if (!ndefTag.isNdefWritable()) {
        throw new Error('NFC tag is read-only');
      }
      await ndefTag.writeNdef(message);
      return;
    }
    if (NfcTagService.hasTechnology(tagInfo, tag.NDEF_FORMATABLE)) {
      const formatableTag = tag.getNdefFormatable(tagInfo);
      if (!formatableTag.isConnected()) {
        formatableTag.connect();
      }
      await formatableTag.format(message);
      return;
    }
    throw new Error('NFC tag does not support NDEF writing');
  }

  static async dispatchTag(context: common.Context, tagId: string): Promise<void> {
    const servers = await ServerManager.listServers(context);
    if (servers.length === 0) {
      throw new Error('No Home Assistant server is registered');
    }
    let errorText = 'NFC tag event failed';
    const results = await Promise.all(servers.map(async (server: ManagedServer): Promise<string> => {
      try {
        await NfcTagService.dispatchToServer(context, server, tagId);
        return '';
      } catch (error) {
        return NetworkService.errorText(error as Error | string | number | boolean | Object);
      }
    }));
    if (results.some((result: string): boolean => result.length === 0)) {
      return;
    }
    for (let i = 0; i < results.length; i++) {
      errorText = results[i];
    }
    throw new Error(errorText);
  }

  private static hasTechnology(tagInfo: tag.TagInfo, technology: number): boolean {
    return Array.isArray(tagInfo.technology) && tagInfo.technology.includes(technology);
  }

  private static fallbackTagId(): string {
    const part = (): string => Math.floor(Math.random() * 0x10000).toString(16).padStart(4, '0');
    return `${part()}${part()}-${part()}-4${part().substring(1)}-${((Math.random() * 4) | 8).toString(16)}${part().substring(1)}-${part()}-${part()}${part()}${part()}`;
  }

  private static tagIdFromRecord(record: tag.NdefRecord): string {
    if (record.tnf !== TAG_RECORD_TNF || NfcTagService.fromBytes(record.rtdType) !== `${TAG_RECORD_DOMAIN}:${TAG_RECORD_TYPE}`) {
      return '';
    }
    const tagId = NfcTagService.fromBytes(record.payload).trim();
    return tagId.length > 0 ? tagId : '';
  }

  private static toBytes(value: string): number[] {
    const bytes: number[] = [];
    for (let i = 0; i < value.length; i++) {
      bytes.push(value.charCodeAt(i));
    }
    return bytes;
  }

  private static fromBytes(value: number[]): string {
    let result = '';
    for (let i = 0; i < value.length; i++) {
      result += String.fromCharCode(value[i]);
    }
    return result;
  }

  private static async dispatchToServer(
    context: common.Context,
    server: ManagedServer,
    tagId: string
  ): Promise<void> {
    const info = server.info;
    const urls: string[] = [];
    if (info.cloudhookUrl.trim().length > 0) {
      urls.push(info.cloudhookUrl.trim());
    }
    let policyError = '';
    let policyBlocked = false;
    const webhookId = info.webhookId.trim();
    if (webhookId.length > 0) {
      try {
        const policy = await HaConnectionPolicyService.resolveServerBaseUrl(context, server.id);
        if (policy.allowed && policy.baseUrl.length > 0) {
          urls.push(`${policy.baseUrl.replace(/\/+$/, '')}/api/webhook/${webhookId}`);
        } else {
          policyBlocked = true;
        }
      } catch (error) {
        policyError = NetworkService.errorText(error as Error | string | number | boolean | Object);
      }
    }
    if (urls.length === 0) {
      if (policyError.length > 0) {
        throw new Error(policyError);
      }
      if (policyBlocked) {
        throw new Error('NFC tag event blocked by connection policy');
      }
      throw new Error('Server is missing mobile-app webhook registration');
    }
    let lastError = 'NFC tag event failed';
    for (let i = 0; i < urls.length; i++) {
      try {
        const body: ScanTagWebhookBody = {
          type: 'scan_tag',
          data: { tag_id: tagId }
        };
        const response = await NetworkService.requestText(urls[i], {
          method: NetworkHttpMethod.POST,
          header: { 'Content-Type': 'application/json' },
          extraData: JSON.stringify(body),
          connectTimeout: 15000,
          readTimeout: 15000
        });
        if (NetworkService.isSuccessStatus(response.responseCode)) {
          return;
        }
        lastError = `HTTP ${response.responseCode}: ${NetworkService.shortText(response.body)}`;
      } catch (error) {
        lastError = NetworkService.errorText(error as Error | string | number | boolean | Object);
      }
    }
    throw new Error(lastError);
  }
}
