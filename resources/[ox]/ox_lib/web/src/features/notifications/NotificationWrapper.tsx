import { useNuiEvent } from '../../hooks/useNuiEvent';
import { fixMoney } from '../../utils/misc';
import { toast, Toaster } from 'react-hot-toast';
import ReactMarkdown from 'react-markdown';
import { Box, Center, createStyles, Group, keyframes, RingProgress, Stack, Text, ThemeIcon } from '@mantine/core';
import React, { useState } from 'react';
import tinycolor from 'tinycolor2';
import type { NotificationProps } from '../../typings';
import MarkdownComponents from '../../config/MarkdownComponents';
import LibIcon from '../../components/LibIcon';

const useStyles = createStyles((theme) => ({
  // Server design kit: dark card, soft border, gold accents, right-to-left Arabic
  // EX_Tii: notifications sit top-center like the big RP servers: a compact dark card with a thin
  // coloured bar on the start side (green = success, red = error, orange = warning, gold = info)
  container: {
    direction: 'rtl',
    minWidth: 300,
    maxWidth: 420,
    height: 'fit-content',
    backgroundColor: 'rgba(14, 15, 20, 0.94)',
    border: '1px solid rgba(255, 255, 255, 0.08)',
    borderInlineStart: '3px solid var(--ntf-accent, #e8b547)',
    color: theme.colors.dark[0],
    padding: '10px 14px',
    borderRadius: 14,
    fontFamily: theme.fontFamily,
    boxShadow: '0 10px 30px rgba(0, 0, 0, 0.45)',
  },
  title: {
    fontWeight: 600,
    fontSize: 14,
    lineHeight: 1.5,
  },
  description: {
    fontSize: 12.5,
    color: theme.colors.dark[2],
    fontFamily: theme.fontFamily,
    lineHeight: 1.6,
    '& p': { margin: 0 },
  },
  descriptionOnly: {
    fontSize: 13.5,
    color: theme.colors.dark[1],
    fontFamily: theme.fontFamily,
    lineHeight: 1.6,
    '& p': { margin: 0 },
  },
}));

const createAnimation = (from: string, to: string, visible: boolean) => keyframes({
  from: {
    opacity: visible ? 0 : 1,
    transform: `translate${from}`,
  },
  to: {
    opacity: visible ? 1 : 0,
    transform: `translate${to}`,
  },
});

const getAnimation = (visible: boolean, position: string) => {
  const animationOptions = visible ? '0.2s ease-out forwards' : '0.4s ease-in forwards'
  let animation: { from: string; to: string };

  if (visible) {
    animation = position.includes('bottom') ? { from: 'Y(30px)', to: 'Y(0px)' } : { from: 'Y(-30px)', to:'Y(0px)' };
  } else {
    if (position.includes('right')) {
      animation = { from: 'X(0px)', to: 'X(100%)' }
    } else if (position.includes('left')) {
      animation = { from: 'X(0px)', to: 'X(-100%)' };
    } else if (position === 'top-center') {
      animation = { from: 'Y(0px)', to: 'Y(-100%)' };
    } else if (position === 'bottom-center') {
      animation = { from: 'Y(0px)', to: 'Y(100%)' };
    } else {
      animation = { from: 'X(0px)', to: 'X(100%)' };
    }
  }

  return `${createAnimation(animation.from, animation.to, visible)} ${animationOptions}`
};

const durationCircle = keyframes({
  '0%': { strokeDasharray: `0, ${15.1 * 2 * Math.PI}` },
  '100%': { strokeDasharray: `${15.1 * 2 * Math.PI}, 0` },
});

const Notifications: React.FC = () => {
  const { classes } = useStyles();
  const [toastKey, setToastKey] = useState(0);

  useNuiEvent<NotificationProps>('notify', (data) => {
    // EX_Tii: lib.notify({ id = 'x', dismiss = true }) removes a notification that is still on screen
    if (data.dismiss) {
      if (data.id !== undefined) toast.dismiss(data.id.toString());
      return;
    }

    if (!data.title && !data.description) return;

    const toastId = data.id?.toString();
    // EX_Tii: duration = 0 keeps the notification on screen until it is dismissed (needs an id)
    const persistent = typeof data.duration === 'number' && data.duration <= 0 && !!toastId;
    const duration = persistent ? Infinity : data.duration || 3000;

    let iconColor: string;
    // EX_Tii: every notification goes to the top-center unless a script asks for the bottom
    let position = data.position && data.position.includes('bottom') ? data.position : 'top-center';

    data.showDuration = persistent ? false : data.showDuration !== undefined ? data.showDuration : true;

    if (toastId) setToastKey(prevKey => prevKey + 1);

    // Backwards compat with old notifications
    switch (position) {
      case 'top':
        position = 'top-center';
        break;
      case 'bottom':
        position = 'bottom-center';
        break;
    }

    if (!data.icon) {
      switch (data.type) {
        case 'error':
          data.icon = 'circle-xmark';
          break;
        case 'success':
          data.icon = 'circle-check';
          break;
        case 'warning':
          data.icon = 'circle-exclamation';
          break;
        default:
          data.icon = 'circle-info';
          break;
      }
    }

    if (!data.iconColor) {
      switch (data.type) {
        case 'error':
          iconColor = 'red.5';
          break;
        case 'success':
          iconColor = 'teal.5';
          break;
        case 'warning':
          iconColor = 'orange.5';
          break;
        default:
          iconColor = 'gold.5';
          break;
      }
    } else {
      iconColor = tinycolor(data.iconColor).toRgbString();
    }
    const accent = { 'red.5': '#ff5f5f', 'teal.5': '#3ddc97', 'orange.5': '#f6a94a', 'gold.5': '#e8b547' }[iconColor] || iconColor;

    toast.custom(
      (t) => (
        <Box
          sx={{
            animation: getAnimation(t.visible, position),
            '--ntf-accent': accent,
            ...data.style,
          } as any}
          className={`${classes.container}`}
        >
          <Group noWrap spacing={12}>
            {data.icon && (
              <>
                {data.showDuration ? (
                  <RingProgress
                    key={toastKey}
                    size={38}
                    thickness={2}
                    sections={[{ value: 100, color: iconColor }]}
                    style={{ alignSelf: !data.alignIcon || data.alignIcon === 'center' ? 'center' : 'start' }}
                    styles={{
                      root: {
                        '> svg > circle:nth-of-type(2)': {
                          animation: `${durationCircle} linear forwards reverse`,
                          animationDuration: `${duration}ms`,
                        },
                        margin: -3,
                      },
                    }}
                    label={
                      <Center>
                        <ThemeIcon
                          color={iconColor}
                          radius="xl"
                          size={30}
                          variant={tinycolor(iconColor).getAlpha() < 0 ? undefined : 'light'}
                        >
                          <LibIcon icon={data.icon} fixedWidth color={iconColor} animation={data.iconAnimation} />
                        </ThemeIcon>
                      </Center>
                    }
                  />
                ) : (
                  <ThemeIcon
                    color={iconColor}
                    radius="xl"
                    size={32}
                    variant={tinycolor(iconColor).getAlpha() < 0 ? undefined : 'light'}
                    style={{ alignSelf: !data.alignIcon || data.alignIcon === 'center' ? 'center' : 'start' }}
                  >
                    <LibIcon icon={data.icon} fixedWidth color={iconColor} animation={data.iconAnimation} />
                  </ThemeIcon>
                )}
              </>
            )}
            <Stack spacing={0}>
              {data.title && <Text className={classes.title}>{fixMoney(data.title)}</Text>}
              {data.description && (
                <ReactMarkdown
                  components={MarkdownComponents}
                  className={`${!data.title ? classes.descriptionOnly : classes.description} description`}
                >
                  {fixMoney(data.description)}
                </ReactMarkdown>
              )}
            </Stack>
          </Group>
        </Box>
      ),
      {
        id: toastId,
        duration: duration,
        position: position,
      }
    );
  });

  // top-center, just under the screen edge (the money cards are top-right, nothing overlaps)
  return <Toaster containerStyle={{ top: 22 }} gutter={8} />;
};

export default Notifications;
