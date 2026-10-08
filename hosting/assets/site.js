// E-posta adresini panoya kopyalama (CSP: yalnızca 'self' betikler)
(function () {
  var toast = document.querySelector('.toast');
  function show(msg) {
    if (!toast) return;
    toast.textContent = msg;
    toast.classList.add('show');
    clearTimeout(show._t);
    show._t = setTimeout(function () { toast.classList.remove('show'); }, 1800);
  }
  document.querySelectorAll('[data-copy]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var text = btn.getAttribute('data-copy');
      var done = function () { show('Adres kopyalandı'); };
      var fail = function () { show('Kopyalanamadı, adresi elle seçebilirsin'); };
      if (navigator.clipboard && window.isSecureContext) {
        navigator.clipboard.writeText(text).then(done, fail);
      } else {
        try {
          var ta = document.createElement('textarea');
          ta.value = text; ta.setAttribute('readonly', '');
          ta.style.position = 'fixed'; ta.style.opacity = '0';
          document.body.appendChild(ta); ta.select();
          document.execCommand('copy') ? done() : fail();
          document.body.removeChild(ta);
        } catch (e) { fail(); }
      }
    });
  });
})();
