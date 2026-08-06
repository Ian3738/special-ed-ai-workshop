/* 共用：文字大小與深淺主題。
   主題與字級在 <head> 的內嵌腳本裡就已套用（避免閃爍），
   這支只負責按鈕狀態、切換行為與偏好儲存。 */
(function(){
  var root = document.documentElement;

  /* 切換主題時暫時關閉所有過場。
     色彩若寫成 var(--x)，過場中途換變數會卡在舊值，分頁列就是這樣糊掉的。 */
  function withoutTransition(fn){
    root.classList.add('theming');
    fn();
    void root.offsetWidth;               // 強制重排，讓新值立即生效
    requestAnimationFrame(function(){
      requestAnimationFrame(function(){ root.classList.remove('theming'); });
    });
  }

  /* ── 文字大小 ── */
  var fsBtns = document.querySelectorAll('button[data-fs]');
  function syncFs(){
    var v = root.getAttribute('data-fs') || 'm';
    fsBtns.forEach(function(b){ b.setAttribute('aria-pressed', String(b.dataset.fs === v)); });
  }
  fsBtns.forEach(function(b){
    b.addEventListener('click', function(){
      root.setAttribute('data-fs', b.dataset.fs);
      syncFs();
      try{ localStorage.setItem('sped-fs', b.dataset.fs); }catch(e){}
    });
  });
  syncFs();

  /* ── 深淺主題 ── */
  var tBtn = document.getElementById('themeBtn');
  function syncTheme(){
    if(!tBtn) return;
    var dark = root.getAttribute('data-theme') === 'dark';
    tBtn.textContent = dark ? '淺色' : '深色';
    tBtn.setAttribute('aria-pressed', String(dark));
    tBtn.setAttribute('aria-label', dark ? '切換為淺色主題' : '切換為深色主題');
  }
  if(tBtn){
    tBtn.addEventListener('click', function(){
      var next = root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
      withoutTransition(function(){ root.setAttribute('data-theme', next); });
      syncTheme();
      try{ localStorage.setItem('sped-theme', next); }catch(e){}
    });
  }
  syncTheme();

  /* 沒存過偏好時跟隨系統 */
  var stored;
  try{ stored = localStorage.getItem('sped-theme'); }catch(e){}
  if(!stored){
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function(e){
      var s; try{ s = localStorage.getItem('sped-theme'); }catch(err){}
      if(s) return;
      withoutTransition(function(){ root.setAttribute('data-theme', e.matches ? 'dark' : 'light'); });
      syncTheme();
    });
  }

  /* ── 頁內章節跳轉列：由各節 h2 自動生成 ── */
  (function(){
    var secs = document.querySelectorAll('main section[aria-labelledby]');
    if(secs.length < 3) return;
    var ph = document.querySelector('header.ph');
    if(!ph) return;

    var bar = document.createElement('nav');
    bar.className = 'toc';
    bar.setAttribute('aria-label', '本頁章節');
    var wrap = document.createElement('div');
    wrap.className = 'wrap';
    var lbl = document.createElement('span');
    lbl.className = 't';
    lbl.textContent = '本頁章節';
    wrap.appendChild(lbl);

    secs.forEach(function(sec){
      var id = sec.getAttribute('aria-labelledby');
      var h  = document.getElementById(id);
      if(!h) return;
      if(!sec.id) sec.id = 'sec-' + id;
      var a = document.createElement('a');
      a.href = '#' + sec.id;
      a.textContent = h.textContent.trim();
      wrap.appendChild(a);
    });

    if(wrap.children.length < 4) return;
    bar.appendChild(wrap);
    ph.insertAdjacentElement('afterend', bar);
  })();

  /* ── 分頁列：把目前頁捲進可視範圍（窄螢幕會橫向捲動） ── */
  var strip = document.querySelector('.tabs .wrap');
  var cur = strip && strip.querySelector('[aria-current="page"]');
  if(strip && cur){
    strip.scrollLeft = Math.max(0, cur.offsetLeft - (strip.clientWidth - cur.offsetWidth) / 2);
  }
})();
