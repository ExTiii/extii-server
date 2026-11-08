import { useCurrentCallValue } from '@os/call/hooks/state';
import { activeNotificationIds } from '@os/new-notifications/state';
import { useEffect, useMemo, useState } from 'react';
import { useRecoilValue } from 'recoil';
import { useSettings } from '../../../apps/settings/hooks/useSettings';
import { isEnvBrowser } from '../../../utils/misc';
import { phoneState } from './state';

// EX_Tii (Moe): the phone is the same size on every screen. The frame is 1000 px tall, drawn for a
// 1440 px tall screen (Moe's); on other screens it is scaled by the screen height so everyone sees the
// same phone. The player's own zoom option (settings) multiplies on top.
const FIT_HEIGHT = 1440;
export const useFitScale = () => {
  const [fit, setFit] = useState<number>(() => Math.max(0.4, Math.min(2, window.innerHeight / FIT_HEIGHT)));
  useEffect(() => {
    const onResize = () => setFit(Math.max(0.4, Math.min(2, window.innerHeight / FIT_HEIGHT)));
    window.addEventListener('resize', onResize);
    onResize();
    return () => window.removeEventListener('resize', onResize);
  }, []);
  return fit;
};

export const usePhoneVisibility = () => {
  const visibility = useRecoilValue(phoneState.visibility);
  const [{ zoom }] = useSettings();
  const activeNotifications = useRecoilValue(activeNotificationIds);
  const [notifVisibility, setNotifVisibility] = useState<boolean>(false);
  const currentCall = useCurrentCallValue();

  const hasNotis = currentCall || activeNotifications.length;

  useEffect(() => {
    if (hasNotis && !visibility) {
      setNotifVisibility(true);
    } else {
      setNotifVisibility(false);
    }
  }, [hasNotis, activeNotifications, visibility]);

  const fit = useFitScale();
  const bottom = useMemo(() => {
    if (!visibility && !isEnvBrowser()) {
      return `${-750 * zoom.value * fit}px`;
    }
    return '0px';
  }, [visibility, zoom, fit]);

  return {
    bottom,
    visibility: notifVisibility || visibility || isEnvBrowser(),
  };
};