(function () {
  const root = document.getElementById('respawn-root');
  const titleEl = document.getElementById('title');
  const countdownWrap = document.getElementById('countdown-wrap');
  const countdownNumber = document.getElementById('countdown-number');
  const countdownLabel = document.getElementById('countdown-label');
  const ringProgress = document.getElementById('ring-progress');
  const promptRespawn = document.getElementById('prompt-respawn');
  const promptRespawnText = document.getElementById('prompt-respawn-text');
  const promptAssist = document.getElementById('prompt-assist');
  const promptAssistText = document.getElementById('prompt-assist-text');

  const RING_CIRCUMFERENCE = 326.7;

  function show() {
    root.classList.remove('hidden');
  }

  function hide() {
    root.classList.add('hidden');
  }

  function setCountdown(visible, seconds, total, label) {
    if (!visible) {
      countdownWrap.classList.add('hidden');
      countdownWrap.style.display = 'none';
      return;
    }
    countdownWrap.style.display = 'flex';
    countdownWrap.classList.remove('hidden');
    countdownNumber.textContent = seconds;
    countdownLabel.textContent = label || 'SECONDS REMAIN';
    const ratio = total > 0 ? Math.max(0, Math.min(1, seconds / total)) : 0;
    ringProgress.style.strokeDashoffset = String(RING_CIRCUMFERENCE * (1 - ratio));
  }

  function setPrompt(el, textEl, visible, text) {
    if (visible) {
      el.classList.remove('hidden');
      if (text) textEl.textContent = text;
    } else {
      el.classList.add('hidden');
    }
  }

  window.addEventListener('message', function (event) {
    const data = event.data || {};

    switch (data.action) {
      case 'respawn:show': {
        show();
        if (data.title) titleEl.textContent = data.title;

        setCountdown(!!data.showCountdown, data.seconds || 0, data.total || 0, data.countdownLabel);
        setPrompt(promptRespawn, promptRespawnText, !!data.showRespawnPrompt, data.respawnText);
        setPrompt(promptAssist, promptAssistText, !!data.showAssistPrompt, data.assistText);
        break;
      }

      case 'respawn:hide': {
        hide();
        break;
      }

      default:
        break;
    }
  });
})();
