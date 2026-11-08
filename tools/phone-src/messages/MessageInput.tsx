import React, { ChangeEvent, useState } from 'react';
import { npcOf } from '../../npcContacts';
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
  const [askOpen, setAskOpen] = useState(true);
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

  // EX_Tii: an NPC contact (the fence, the broker): a list of what you can ask, each with what it does
  const npc = npcOf(String(messageConversation.conversationList || activeMessageConversation?.conversationList || ''));
  const options = npc?.options || [];
  const quickSend = async (text: string) => {
    setAskOpen(false);
    await sendMessage({
      conversationId: messageConversation.id,
      conversationList: activeMessageConversation.conversationList,
      message: text,
      tgtPhoneNumber: messageConversation.participant,
    });
  };

  return (
    <div className="px-2">
      {options.length > 0 && (
        <div dir="rtl" className="mb-2 overflow-hidden rounded-xl border border-[#e8b547]/30 bg-[#e8b547]/[0.06]">
          <button
            onClick={() => setAskOpen(!askOpen)}
            className="flex w-full items-center justify-between px-3 py-2 text-right"
          >
            <span>
              <span className="block text-[14px] font-bold text-[#c8952a] dark:text-[#e8b547]">
                ماذا تطلب من {npc?.name}؟
              </span>
              {askOpen && npc?.about && (
                <span className="block text-[11.5px] leading-snug text-neutral-500 dark:text-neutral-400">{npc.about}</span>
              )}
            </span>
            <span className="text-[13px] font-semibold text-[#c8952a] dark:text-[#e8b547]">{askOpen ? 'إخفاء ▾' : 'الخيارات ▴'}</span>
          </button>
          {askOpen && (
            <div className="max-h-[230px] overflow-y-auto px-2 pb-2">
              {options.map((o) => (
                <React.Fragment key={o.label}>
                  {o.group && (
                    <div className="px-1 pb-1 pt-2 text-[11px] font-bold text-neutral-400">{o.group}</div>
                  )}
                  <button
                    onClick={() => quickSend(o.text)}
                    className="mb-1 block w-full rounded-lg bg-white px-3 py-2 text-right shadow-sm hover:bg-[#e8b547]/15 dark:bg-neutral-800 dark:hover:bg-[#e8b547]/15"
                  >
                    <span className="block text-[13.5px] font-bold text-neutral-900 dark:text-white">{o.label}</span>
                    <span className="block text-[11.5px] leading-snug text-neutral-500 dark:text-neutral-400">{o.hint}</span>
                  </button>
                </React.Fragment>
              ))}
            </div>
          )}
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
