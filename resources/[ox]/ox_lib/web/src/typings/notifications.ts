import { ToastPosition } from 'react-hot-toast';
import { IconProp } from '@fortawesome/fontawesome-svg-core';
import { Sx } from '@mantine/core';
import { IconAnimation } from '../components/LibIcon';

export interface NotificationProps {
  dismiss?: boolean;
  style?: Sx;
  description?: string;
  title?: string;
  duration?: number;
  showDuration?: boolean;
  icon?: IconProp;
  iconColor?: string;
  iconAnimation?: IconAnimation;
  position?: ToastPosition | 'top' | 'bottom';
  id?: number | string;
  type?: string;
  alignIcon?: 'top' | 'center';
  // EX_Tii: a progress bar inside the notification (the level bar): from/to in %, the XP numbers count up
  progress?: { from?: number; to: number; cur?: number; prev?: number; need?: number; color?: string };
}
