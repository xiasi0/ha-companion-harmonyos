import { Want } from '@kit.AbilityKit';

export interface CardEntityDetailRequest {
  entityId: string;
  serverInstanceId: string;
}

export class CardEntityDetailLaunchService {
  static readonly ACTION: string = 'ha.open_entity_detail';
  static readonly ENTITY_ID_PARAM: string = 'entityId';
  static readonly SERVER_INSTANCE_ID_PARAM: string = 'serverInstanceId';
  static readonly PENDING_ENTITY_ID_KEY: string = 'cardPendingEntityDetailEntityId';
  static readonly PENDING_SERVER_ID_KEY: string = 'cardPendingEntityDetailServerInstanceId';
  static readonly PENDING_TICK_KEY: string = 'cardPendingEntityDetailTick';

  static requestFromWant(want: Want): CardEntityDetailRequest | undefined {
    const params = want.parameters;
    if (!params) {
      return undefined;
    }
    if (CardEntityDetailLaunchService.stringParam(params, 'action') !== CardEntityDetailLaunchService.ACTION) {
      return undefined;
    }
    const entityId = CardEntityDetailLaunchService.stringParam(params, CardEntityDetailLaunchService.ENTITY_ID_PARAM);
    if (!CardEntityDetailLaunchService.isValidEntityId(entityId)) {
      return undefined;
    }
    return {
      entityId,
      serverInstanceId: CardEntityDetailLaunchService.stringParam(params, CardEntityDetailLaunchService.SERVER_INSTANCE_ID_PARAM)
    };
  }

  static publishPending(request: CardEntityDetailRequest): void {
    AppStorage.setOrCreate<string>(CardEntityDetailLaunchService.PENDING_ENTITY_ID_KEY, request.entityId);
    AppStorage.setOrCreate<string>(CardEntityDetailLaunchService.PENDING_SERVER_ID_KEY, request.serverInstanceId);
    const currentTick = AppStorage.get<number>(CardEntityDetailLaunchService.PENDING_TICK_KEY) ?? 0;
    AppStorage.setOrCreate<number>(CardEntityDetailLaunchService.PENDING_TICK_KEY, currentTick + 1);
  }

  static isValidEntityId(entityId: string): boolean {
    const value = entityId.trim();
    const dot = value.indexOf('.');
    if (dot <= 0 || dot !== value.lastIndexOf('.') || dot >= value.length - 1) {
      return false;
    }
    return CardEntityDetailLaunchService.isValidEntityPart(value.substring(0, dot)) &&
      CardEntityDetailLaunchService.isValidEntityPart(value.substring(dot + 1));
  }

  static moreInfoScript(entityId: string): string {
    const encoded = JSON.stringify(entityId);
    return `(function(){` +
      `var entityId=${encoded};` +
      `function q(root,selector){return root&&typeof root.querySelector==='function'?root.querySelector(selector):null;}` +
      `function isUpdated(el){return el&&el.hasUpdated!==false;}` +
      `function dashboardPanelUrl(panels){` +
      `if(!panels){return '';}` +
      `if(panels.home&&panels.home.component_name==='home'){return 'home';}` +
      `if(panels.lovelace&&panels.lovelace.component_name==='lovelace'){return 'lovelace';}` +
      `for(var key in panels){if(!Object.prototype.hasOwnProperty.call(panels,key)){continue;}var panel=panels[key];` +
      `if(panel&&(panel.component_name==='home'||panel.component_name==='lovelace')){return key;}}` +
      `return '';` +
      `}` +
      `function notifyClosed(){` +
      `if(window.__haHarmonyCardMoreInfoClosedNotified){return;}` +
      `window.__haHarmonyCardMoreInfoClosedNotified=true;` +
      `try{externalApp.externalBus(JSON.stringify({type:'harmony_card_entity_detail_closed',payload:{entityId:entityId}}));}catch(e){}` +
      `}` +
      `function isDialogOpen(ha){` +
      `if(history.state&&history.state.dialog==='ha-more-info-dialog'){return true;}` +
      `var dialog=ha&&ha.shadowRoot?q(ha.shadowRoot,'ha-more-info-dialog'):null;` +
      `if(!dialog){return false;}` +
      `if(dialog.open===true||dialog.opened===true||(dialog.hasAttribute&&dialog.hasAttribute('open'))){return true;}` +
      `var inner=q(dialog.shadowRoot,'ha-dialog,mwc-dialog');` +
      `return !!(inner&&(inner.open===true||inner.opened===true||(inner.hasAttribute&&inner.hasAttribute('open'))));` +
      `}` +
      `function installCloseWatcher(ha){` +
      `window.__haHarmonyCardMoreInfoClosedNotified=false;` +
      `window.__haHarmonyCardMoreInfoSeenOpen=false;` +
      `function check(){` +
      `var open=isDialogOpen(ha);` +
      `if(open){window.__haHarmonyCardMoreInfoSeenOpen=true;return;}` +
      `if(window.__haHarmonyCardMoreInfoSeenOpen){notifyClosed();}` +
      `}` +
      `window.__haHarmonyCardMoreInfoCheck=check;` +
      `function schedule(){Promise.resolve().then(function(){var fn=window.__haHarmonyCardMoreInfoCheck;if(typeof fn==='function'){fn();}});}` +
      `if(!window.__haHarmonyCardMoreInfoWatcherInstalled){` +
      `window.__haHarmonyCardMoreInfoWatcherInstalled=true;` +
      `window.addEventListener('popstate',schedule,true);` +
      `window.addEventListener('hashchange',schedule,true);` +
      `window.addEventListener('location-changed',schedule,true);` +
      `window.addEventListener('close-dialog',schedule,true);` +
      `window.addEventListener('dialog-closed',schedule,true);` +
      `window.__haHarmonyCardMoreInfoObserver=new MutationObserver(schedule);` +
      `}` +
      `try{` +
      `var observer=window.__haHarmonyCardMoreInfoObserver;` +
      `if(observer){observer.disconnect();observer.observe(ha.shadowRoot||document,{childList:true,subtree:true,attributes:true,attributeFilter:['open','aria-hidden']});}` +
      `}catch(e){}` +
      `schedule();` +
      `}` +
      `function readiness(ha){` +
      `if(!ha){return 'pending';}` +
      `if(!ha.hass||!ha.hass.states||!ha.shadowRoot||!isUpdated(ha)){return 'pending';}` +
      `if(!ha.hass.states[entityId]){return 'missing_entity';}` +
      `var panelUrl=ha.hass.panelUrl||'';` +
      `var slash=location.pathname.indexOf('/',1);` +
      `var pathPanel=location.pathname==='/'?'':(slash<0?location.pathname.substring(1):location.pathname.substring(1,slash));` +
      `if(pathPanel&&panelUrl!==pathPanel){return 'pending';}` +
      `var panelInfo=panelUrl&&ha.hass.panels?ha.hass.panels[panelUrl]:null;` +
      `if(!panelUrl||!panelInfo){return 'pending';}` +
      `if(panelInfo.component_name!=='lovelace'&&panelInfo.component_name!=='home'){` +
      `var targetPanel=dashboardPanelUrl(ha.hass.panels);` +
      `return targetPanel?'not_dashboard:'+encodeURIComponent(targetPanel):'not_dashboard';` +
      `}` +
      `var main=q(ha.shadowRoot,'home-assistant-main');` +
      `if(!main||!main.shadowRoot||!isUpdated(main)){return 'pending';}` +
      `var resolver=q(main.shadowRoot,'partial-panel-resolver');` +
      `if(!resolver||!isUpdated(resolver)){return 'pending';}` +
      `var panel=q(resolver,panelInfo.component_name==='home'?'ha-panel-home':'ha-panel-lovelace');` +
      `if(!panel||!panel.shadowRoot||!isUpdated(panel)){return 'pending';}` +
      `var root=q(panel.shadowRoot,'hui-root');` +
      `if(!root||!root.shadowRoot||!isUpdated(root)){return 'pending';}` +
      `var viewContainer=q(root.shadowRoot,'hui-view-container#view');` +
      `if(!viewContainer||!isUpdated(viewContainer)){return 'pending';}` +
      `return 'ready';` +
      `}` +
      `function clearReadyWatcher(){` +
      `try{` +
      `var observer=window.__haHarmonyCardMoreInfoReadyObserver;` +
      `if(observer){observer.disconnect();}` +
      `window.__haHarmonyCardMoreInfoReadyCheck=null;` +
      `}catch(e){}` +
      `}` +
      `function notifyReady(){` +
      `if(window.__haHarmonyCardMoreInfoReadyNotified){return;}` +
      `window.__haHarmonyCardMoreInfoReadyNotified=true;` +
      `clearReadyWatcher();` +
      `try{externalApp.externalBus(JSON.stringify({type:'harmony_card_entity_detail_ready',payload:{entityId:entityId}}));}catch(e){}` +
      `}` +
      `function installReadyWatcher(){` +
      `window.__haHarmonyCardMoreInfoReadyNotified=false;` +
      `function observeReadyRoots(){` +
      `try{` +
      `var observer=window.__haHarmonyCardMoreInfoReadyObserver;` +
      `if(!observer){return;}` +
      `function observe(root){if(root){observer.observe(root,{childList:true,subtree:true,attributes:true});}}` +
      `var ha=document.querySelector('home-assistant');` +
      `observe(document.documentElement);` +
      `if(ha){observe(ha.shadowRoot);}` +
      `var main=ha&&ha.shadowRoot?q(ha.shadowRoot,'home-assistant-main'):null;` +
      `if(main){observe(main.shadowRoot);}` +
      `var resolver=main&&main.shadowRoot?q(main.shadowRoot,'partial-panel-resolver'):null;` +
      `var panel=resolver?q(resolver,'ha-panel-lovelace,ha-panel-home'):null;` +
      `if(panel){observe(panel.shadowRoot);}` +
      `var root=panel&&panel.shadowRoot?q(panel.shadowRoot,'hui-root'):null;` +
      `if(root){observe(root.shadowRoot);}` +
      `}catch(e){}` +
      `}` +
      `function checkReady(){` +
      `observeReadyRoots();` +
      `var state=readiness(document.querySelector('home-assistant'));` +
      `if(state==='ready'||state==='missing_entity'||state==='not_dashboard'||state.indexOf('not_dashboard:')===0){notifyReady();}` +
      `}` +
      `window.__haHarmonyCardMoreInfoReadyCheck=checkReady;` +
      `function scheduleReady(){Promise.resolve().then(function(){var fn=window.__haHarmonyCardMoreInfoReadyCheck;if(typeof fn==='function'){fn();}});}` +
      `if(!window.__haHarmonyCardMoreInfoReadyWatcherInstalled){` +
      `window.__haHarmonyCardMoreInfoReadyWatcherInstalled=true;` +
      `window.addEventListener('location-changed',scheduleReady,true);` +
      `window.addEventListener('popstate',scheduleReady,true);` +
      `window.addEventListener('hashchange',scheduleReady,true);` +
      `window.__haHarmonyCardMoreInfoReadyObserver=new MutationObserver(scheduleReady);` +
      `}` +
      `scheduleReady();` +
      `}` +
      `var ha=document.querySelector('home-assistant');` +
      `var state=readiness(ha);` +
      `if(state==='missing_entity'){return 'missing_entity';}` +
      `if(state==='not_dashboard'||state.indexOf('not_dashboard:')===0){return state;}` +
      `if(state!=='ready'){installReadyWatcher();return 'pending';}` +
      `installCloseWatcher(ha);` +
      `if(isDialogOpen(ha)){return 'opened';}` +
      `ha.dispatchEvent(new CustomEvent('hass-more-info',{detail:{entityId:entityId},bubbles:true,composed:true}));` +
      `var check=window.__haHarmonyCardMoreInfoCheck;if(typeof check==='function'){Promise.resolve().then(check);}` +
      `return 'opened';` +
      `})();`;
  }

  static closeMoreInfoScript(): string {
    return `(function(){` +
      `var ha=document.querySelector('home-assistant');` +
      `var dialog=ha&&ha.shadowRoot?ha.shadowRoot.querySelector('ha-more-info-dialog'):null;` +
      `if(dialog){dialog.dispatchEvent(new CustomEvent('close-dialog',{bubbles:true,composed:true}));return true;}` +
      `if(history.state&&history.state.dialog==='ha-more-info-dialog'){history.back();return true;}` +
      `return false;` +
      `})();`;
  }

  static navigateToDashboardScript(dashboardUrl: string): string {
    const encoded = JSON.stringify(dashboardUrl);
    return `(function(){` +
      `var target=${encoded};` +
      `if(!target){return false;}` +
      `try{` +
      `var url=new URL(target,location.href);` +
      `if(url.origin!==location.origin){url=new URL(url.pathname+url.search+url.hash,location.href);}` +
      `var path=url.pathname+url.search+url.hash;` +
      `if((location.pathname+location.search+location.hash)===path){return true;}` +
      `try{history.replaceState(history.state,'',path);}catch(e){return false;}` +
      `window.dispatchEvent(new CustomEvent('location-changed',{detail:{replace:true}}));` +
      `return true;` +
      `}catch(e){return false;}` +
      `})();`;
  }

  private static stringParam(params: Record<string, Object>, key: string): string {
    const value = params[key];
    return typeof value === 'string' ? value.trim() : '';
  }

  private static isValidEntityPart(value: string): boolean {
    if (value.length === 0 || value.startsWith('_') || value.endsWith('_') || value.indexOf('__') >= 0) {
      return false;
    }
    for (let i = 0; i < value.length; i++) {
      const code = value.charCodeAt(i);
      const isDigit = code >= 48 && code <= 57;
      const isLower = code >= 97 && code <= 122;
      if (!isDigit && !isLower && value[i] !== '_') {
        return false;
      }
    }
    return true;
  }
}
