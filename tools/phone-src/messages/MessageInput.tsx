import React, { ChangeEvent, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Paper, Box, Button, ButtonGroup } from '@mui/material';
import SendIcon from '@mui/icons-material/Send';
import MicIcon from '@mui/icons-material/Mic';
import IosShareIcon from '@mui/icons-material/IosShare';
import { NPWDInput, NPWDTextarea, TextField } from '@ui/components/Input';
import { useMessageAPI } from '../../hooks/useMessageAPI';
import { MessageConversation } from '@typings/messages';
import useMessages from '../../hooks/useMessages';
import { useWordFilter } from '@os/wordfilter/hooks/useWordFilter';
import { useConfig } from '@os/phone/hooks';
import { Image, Mic, SendHorizonal, SendHorizontal } from 'lucide-react';

interface IProps {
  onAddImageClick(): void;

  onVoiceClick: () => void;
  messageConversation: MessageConversation | undefined;
  messageGroupName: string | undefined;
  voiceEnabled: boolean;
}

const MessageInput = ({
  messageConversation,
  onAddImageClick,
  onVoiceClick,
  voiceEnabled,
}: IProps) => {
  const [t] = useTranslation();
  const [message, setMessage] = useState('');
  const { sendMessage } = useMessageAPI();
  const { activeMessageConversation } = useMessages();
  const { clean } = useWordFilter();

  const handleSubmit = async () => {
    if (message.trim()) {
      await sendMessage({
        conversationId: messageConversation.id,
        conversationList: activeMessageConversation.conversationList,
        message: clean(message),
        tgtPhoneNumber: messageConversation.participant,
      });
      setMessage('');
    }
  };

  const handleKeyPress = async (event: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      event.stopPropagation();
      await handleSubmit();
    }
  };

  const handleChange = (e: ChangeEvent<HTMLTextAreaElement | HTMLInputElement>) => {
    setMessage(e.currentTarget.value);
  };

  if (!messageConversation.id) return null;

  // EX_Tii: the fence (المصرّف) and the broker (الوسيط) answer fixed words: tap a line instead of typing it
  const QUICK_BY_NUMBER: Record<string, [string, string][]> = {
    '555-0187': [
      ['وين مكانك اليوم؟', 'وين مكانك اليوم؟'],
      ['عندك بيت؟', 'عندك شغل؟ بيت'],
      ['مهام اليوم', 'شو مهام اليوم؟'],
      ['بنك', 'عندك خبر عن بنك؟'],
      ['شاحنة مصفّحة', 'أريد شاحنة مصفّحة'],
      ['مزرعة الكارتيل', 'أريد المزرعة'],
      ['القافلة', 'أريد القافلة'],
      ['تحضير بنك', 'تحضير بنك'],
      ['تحضير مزرعة', 'تحضير مزرعة'],
      ['تحضير قافلة', 'تحضير قافلة'],
      ['تحضير يخت', 'تحضير يخت'],
    ],
    '555-0420': [
      ['الفلاشات', 'عندك فلاشات؟'],
      ['فلاشة خضراء', 'أريد فلاشة خضراء'],
      ['فلاشة زرقاء', 'أريد فلاشة زرقاء'],
      ['بنك اليوم', 'أي بنك اليوم؟'],
      ['خزنة باسيفيك', 'شو في باسيفيك؟'],
      ['اليخت', 'أريد اليخت'],
      ['الكبيرة', 'شو أخبار الكبيرة؟'],
      ['أطالب بها', 'أطالب بها'],
      ['ابدأ', 'ابدأ'],
    ],
  };
  // (the conversation list is "my number+his number"; participant is MY number)
  const others = String(messageConversation.conversationList || activeMessageConversation?.conversationList || '')
    .split('+')
    .map((n) => n.replace(/\s/g, ''));
  const QUICK = others.map((n) => QUICK_BY_NUMBER[n]).find(Boolean) || [];
  const isFence = QUICK.length > 0;
  const quickSend = async (text: string) => {
    await sendMessage({
      conversationId: messageConversation.id,
      conversationList: activeMessageConversation.conversationList,
      message: text,
      tgtPhoneNumber: messageConversation.participant,
    });
  };

  return (
    <div className="px-2">
      {isFence && (
        <div dir="rtl" className="mb-2 flex gap-1.5 overflow-x-auto pb-1" style={{ scrollbarWidth: 'none' }}>
          {QUICK.map(([label, text]) => (
            <button
              key={label}
              onClick={() => quickSend(text)}
              className="shrink-0 rounded-full border border-[#e8b547]/50 bg-[#e8b547]/10 px-3 py-1.5 text-[13px] font-semibold text-[#e8b547] hover:bg-[#e8b547]/25"
            >
              {label}
            </button>
          ))}
        </div>
      )}
      <div className="flex items-center space-x-2 rounded-md px-2 dark:bg-neutral-800">
        <button
          onClick={onAddImageClick}
          className="h-14 dark:text-white hover:dark:text-green-500"
        >
          <Image size={24} />
        </button>
        <NPWDTextarea
          rows={1}
          className="resize-none"
          onKeyDown={handleKeyPress}
          value={message}
          onChange={handleChange}
          placeholder={t('MESSAGES.NEW_MESSAGE')}
        />
        <div className="flex items-center space-x-2">
          {voiceEnabled && (
            <button onClick={onVoiceClick} className="hover:text-green-500">
              <Mic size={24} />
            </button>
          )}

          <button
            onClick={handleSubmit}
            className="rounded-lg bg-green-600 p-2 text-white hover:bg-green-700"
          >
            <SendHorizontal size={24} />
          </button>
        </div>
      </div>
    </div>
  );
};

export default MessageInput;
