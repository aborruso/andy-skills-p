// Extracts post + comments from a LinkedIn post page and returns JSON.
// Hooks: LinkedIn's Ember semantic classes (`comments-comment-entity`,
// `update-components-*`), not the hashed utility classes and not the UI text:
// those names have been stable for years and do not depend on the UI language.
// Every field comes from its own selector, never from the position of a line in
// innerText: lines shift around with badges, verification marks and translations.
// `hooks` reports how many nodes each selector matched: when extraction comes
// back empty, it says right away which hook died.
(() => {
  const NB = / /g;
  const clean = (el) => (el ? el.innerText : '').replace(NB, ' ').trim();
  const one = (root, sel) => {
    const e = root.querySelector(sel);
    return e ? clean(e) : '';
  };
  // "Jane Doe Jane Doe • 2nd Premium • 2nd" -> "Jane Doe": LinkedIn repeats the
  // name in a visually-hidden node and appends degree of connection and badges.
  const name = (s) => {
    const first = s.split('\n').map(x => x.trim()).filter(Boolean)[0] || '';
    return first
      .replace(/\s*•.*$/, '')
      .replace(/\s*(Profilo\s+)?(Premium|Verificato|Verified)\s*$/i, '')
      .trim();
  };
  const dedup = (s) => {
    const t = name(s);
    return t || s.split('\n')[0] || '';
  };

  const entities = [...document.querySelectorAll('article.comments-comment-entity')];

  // --- post -------------------------------------------------------------
  let postBox = document.querySelector('.update-components-update-v2__commentary');
  if (!postBox) {
    postBox = [...document.querySelectorAll('.update-components-text')]
      .filter(b => !entities.some(n => n.contains(b)))[0] || null;
  }
  const postText = postBox ? clean(postBox) : '';
  const postAuthor = dedup(one(document, '.update-components-actor__title'));
  const postHeadline = (() => {
    const d = one(document, '.update-components-actor__description');
    // same visually-hidden duplication as the title: the headline appears twice
    const l = d.split('\n').map(x => x.trim()).filter(Boolean);
    return l[0] || '';
  })();
  const postTime = (one(document, '.update-components-actor__sub-description')
    .split('•')[0] || '').trim();

  const declared = (one(document, '.social-details-social-counts__comments')
    .match(/\d[\d.]*/) || [''])[0];

  // --- comments ---------------------------------------------------------
  const comments = entities.map(n => ({
    urn: n.getAttribute('data-id') || '',
    // a reply is an article nested inside its parent comment's article
    reply: !!(n.parentElement && n.parentElement.closest('article.comments-comment-entity')),
    author: dedup(one(n, '.comments-comment-meta__description-title')),
    headline: one(n, '.comments-comment-meta__description-subtitle').split('\n')[0].trim(),
    time: one(n, '.comments-comment-meta__data time, time').split('\n')[0].trim(),
    reactions: one(n, '[class*="comments-comment-social-bar__reactions-count"]').replace(/\s+/g, ' ').trim(),
    text: one(n, '.comments-comment-item__main-content')
  })).filter(c => c.text);

  // de-duplicate on the URN: the list is virtualised and can repeat a node
  const seen = new Set();
  const uniq = comments.filter(c => !c.urn || (!seen.has(c.urn) && seen.add(c.urn)));

  return JSON.stringify({
    postAuthor, postHeadline, postTime, postText,
    declaredComments: declared,
    comments: uniq,
    hooks: {
      entities: entities.length,
      commentary: document.querySelectorAll('.update-components-update-v2__commentary').length,
      updateText: document.querySelectorAll('.update-components-text').length,
      socialCounts: document.querySelectorAll('.social-details-social-counts__comments').length
    }
  });
})()
