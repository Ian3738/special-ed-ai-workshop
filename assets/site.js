/* 共用：文字大小與深淺主題。偏好存 localStorage，跨頁一致。 */
(function(){
  var root = document.documentElement;

  var fsBtns = document.querySelectorAll('button[data-fs]');
  function setFs(v, save){
    root.setAttribute('data-fs', v);
    fsBtns.forEach(function(b){ b.setAttribute('aria-pressed', String(b.dataset.fs === v)); });
    if(save){ try{ localStorage.setItem('sped-fs', v); }catch(e){} }
  }
  fsBtns.forEach(function(b){
    b.addEventListener('click', function(){ setFs(b.dataset.fs, true); });
  });

  var tBtn = document.getElementById('themeBtn');
  function setTheme(t, save){
    root.setAttribute('data-theme', t);
    var dark = t === 'dark';
    if(tBtn){
      tBtn.textContent = dark ? '淺色' : '深色';
      tBtn.setAttribute('aria-pressed', String(dark));
      tBtn.setAttribute('aria-label', dark ? '切換為淺色主題' : '切換為深色主題');
    }
    if(save){ try{ localStorage.setItem('sped-theme', t); }catch(e){} }
  }
  if(tBtn){
    tBtn.addEventListener('click', function(){
      setTheme(root.getAttribute('data-theme') === 'dark' ? 'light' : 'dark', true);
    });
  }

  var savedFs, savedTheme;
  try{
    savedFs = localStorage.getItem('sped-fs');
    savedTheme = localStorage.getItem('sped-theme');
  }catch(e){}

  setFs(savedFs || 'm', false);
  if(savedTheme){
    setTheme(savedTheme, false);
  }else{
    var mq = window.matchMedia('(prefers-color-scheme: dark)');
    setTheme(mq.matches ? 'dark' : 'light', false);
    mq.addEventListener('change', function(e){
      var stored;
      try{ stored = localStorage.getItem('sped-theme'); }catch(err){}
      if(!stored){ setTheme(e.matches ? 'dark' : 'light', false); }
    });
  }
})();
