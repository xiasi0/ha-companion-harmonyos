import { Want } from '@kit.AbilityKit';
import { formInfo } from '@kit.FormKit';

export class CardFormWantParser {
  static formId(want: Want): string {
    const params = want.parameters;
    if (!params) {
      return '';
    }
    const raw = params[formInfo.FormParam.IDENTITY_KEY] ??
      params['ohos.extra.param.key.form_identity'] ??
      params['formId'] ??
      params['form_id'];
    if (typeof raw === 'string') {
      return raw;
    }
    if (typeof raw === 'number') {
      return String(raw);
    }
    const rawParams = params['params'];
    if (typeof rawParams === 'string') {
      try {
        const parsed = JSON.parse(rawParams) as Record<string, string | number>;
        const parsedFormId = parsed['formId'] ?? parsed['form_id'] ?? parsed['ohos.extra.param.key.form_identity'];
        if (typeof parsedFormId === 'string') {
          return parsedFormId;
        }
        if (typeof parsedFormId === 'number') {
          return String(parsedFormId);
        }
      } catch (_) {
        return '';
      }
    }
    return '';
  }

  static editFormId(want: Want): string {
    const params = want.parameters;
    if (!params) {
      return '';
    }
    const raw = params['ohos.extra.param.key.edit_form_id'];
    if (typeof raw === 'string') {
      return raw.trim();
    }
    if (typeof raw === 'number') {
      return String(raw);
    }
    return '';
  }

  static formName(want: Want): string {
    const params = want.parameters;
    if (!params) {
      return '';
    }
    const raw = params['ohos.extra.param.key.form_name'] ?? params['formName'] ?? params['form_name'];
    if (typeof raw === 'string') {
      return raw.trim();
    }
    const rawParams = params['params'];
    if (typeof rawParams === 'string') {
      try {
        const parsed = JSON.parse(rawParams) as Record<string, string>;
        const parsedName = parsed['ohos.extra.param.key.form_name'] ?? parsed['formName'] ?? parsed['form_name'];
        return typeof parsedName === 'string' ? parsedName.trim() : '';
      } catch (_) {
        return '';
      }
    }
    return '';
  }

  static cardType(want: Want): string {
    const params = want.parameters;
    if (!params) {
      return '';
    }
    const raw = params['cardType'] ?? params['card_type'] ?? params['ohos.extra.param.key.card_type'];
    const normalized = CardFormWantParser.normalizeCardType(raw);
    if (normalized.length > 0) {
      return normalized;
    }
    const rawParams = params['params'];
    if (typeof rawParams === 'string') {
      try {
        const parsed = JSON.parse(rawParams) as Record<string, string | number>;
        const parsedType = CardFormWantParser.normalizeCardType(
          parsed['cardType'] ?? parsed['card_type'] ?? parsed['ohos.extra.param.key.card_type']
        );
        if (parsedType.length > 0) {
          return parsedType;
        }
      } catch (_) {
        return '';
      }
    }
    return CardFormWantParser.cardTypeFromFormName(CardFormWantParser.formName(want));
  }

  static formDimension(want: Want): string {
    const params = want.parameters;
    if (!params) {
      return '';
    }
    const raw = params['ohos.extra.param.key.form_dimension'] ?? params['formDimension'] ?? params['form_dimension'];
    if (typeof raw === 'string') {
      return raw.trim();
    }
    if (typeof raw === 'number') {
      return String(raw);
    }
    return '';
  }

  static event(message: string): string {
    try {
      const parsed = JSON.parse(message) as Record<string, string>;
      const event = parsed['event'];
      return typeof event === 'string' ? event : '';
    } catch (_) {
      return '';
    }
  }

  private static normalizeCardType(raw: Object | string | number | boolean | undefined): string {
    if (typeof raw !== 'string') {
      return '';
    }
    const value = raw.trim();
    if (value === 'light' || value === 'media' || value === 'scene' || value === 'camera') {
      return value;
    }
    return '';
  }

  private static cardTypeFromFormName(formName: string): string {
    const value = formName.trim();
    if (value === 'harmony_media_service_card') {
      return 'media';
    }
    if (value === 'harmony_light_service_card') {
      return 'light';
    }
    if (value === 'harmony_scene_service_card') {
      return 'scene';
    }
    if (value === 'harmony_camera_service_card') {
      return 'camera';
    }
    return '';
  }
}
