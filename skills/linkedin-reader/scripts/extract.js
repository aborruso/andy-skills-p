// Extracts post + comments from a LinkedIn post page and returns JSON.
//
// LinkedIn replaced the Ember web client with a server-driven UI renderer
// (`data-component-type="LazyColumn"`): as of 2026-09-11 there is no `article`
// element in the page, no `data-id`, and every surviving class is hashed
// (`_4a74b613`). The only stable hooks left are `data-testid` and
// `data-sdui-anchor-id`, and the shape of each block.
//
// Anchor of everything: `[data-testid="expandable-text-box"]` — one node for the
// post body and one for each comment. From there we walk up to the block that
// owns it. Author, time and reactions have no hook of their own, so inside a
// block they are read by position; the position is scoped to the block, not to a
// line of the whole page's innerText.
//
// `hooks` reports how many nodes each selector matched: when extraction comes
// back empty, it says right away which hook died.
(() => {
  const NB = / /g;
  const clean = (el) => (el ? el.innerText : '').replace(NB, ' ').trim();
  const lines = (s) => s.split('\n').map(x => x.trim()).filter(Boolean);
  const DEGREE = /^[•·]?\s*\d+°\+?$/;

  // "Eric Raszewski, MBA, Profilo Premium 2°" -> "Eric Raszewski, MBA"
  // The first text node of an identity link is an accessibility composite: the
  // name followed by the Premium / Verified badges and by the degree of
  // connection, all in the UI language. The degree marker is language
  // independent, so the first cut hangs off it; the badge words are then peeled
  // off by name. The remaining case is your own comments, marked "Tu"/"You"
  // instead of a degree: that word is not guessable, but it is spelled out in
  // the link's second text node ("• Tu"), so it gets taken from there.
  const BADGE = /\s*(Profilo\s+)?(Premium|Verificato|Verified)\s*$/i;
  const name = (el) => {
    if (!el) return '';
    const l = [...el.querySelectorAll('*')]
      .filter(x => x.children.length === 0 && x.textContent.trim())
      .map(x => x.textContent.replace(NB, ' ').trim());
    let s = (l[0] || '').replace(/\s*[•·]?\s*\d+°\+?\s*$/, '');
    // Only a node that opens with the bullet is the badge row; a bare second
    // node is the visible copy of the name and must not be cut off the first.
    const bullet = (l[1] || '').match(/^[•·]\s*(.+)$/);
    const mark = bullet ? bullet[1].trim() : '';
    if (mark && mark.length <= 12 && !DEGREE.test(mark) && s.endsWith(mark)) {
      s = s.slice(0, -mark.length);
    }
    while (BADGE.test(s)) s = s.replace(BADGE, '');
    return s.replace(/\s*[•·,]\s*$/, '').trim();
  };

  // Any LinkedIn identity page: members, companies, schools, showcase pages.
  const PROFILE = 'a[href*="linkedin.com/in/"], a[href*="linkedin.com/company/"],'
    + ' a[href*="linkedin.com/school/"], a[href*="linkedin.com/showcase/"],'
    + ' a[href^="/in/"], a[href^="/company/"], a[href^="/school/"], a[href^="/showcase/"]';
  // The first ancestor carrying a profile link that is NOT part of the body.
  // The exclusion is required: a mention inside a comment is itself a profile
  // link, and without it the walk stops on the wrong node.
  const ownerOf = (box) => {
    let e = box.parentElement;
    while (e && e !== document.body) {
      const a = [...e.querySelectorAll(PROFILE)].filter(x => !box.contains(x));
      if (a.length) return e;
      e = e.parentElement;
    }
    return null;
  };
  // The avatar is a profile link too and carries no text: take the first one
  // that actually spells the name out.
  const actorLink = (block, box) =>
    [...block.querySelectorAll(PROFILE)]
      .filter(x => !box.contains(x) && x.innerText.trim())[0] || null;
  const leavesOf = (root, skip) => [...root.querySelectorAll('*')]
    .filter(e => e.children.length === 0 && e.textContent.trim() && (!skip || !skip.contains(e)))
    .map(e => e.textContent.replace(NB, ' ').trim());

  const boxes = [...document.querySelectorAll('[data-testid="expandable-text-box"]')];

  // --- comment blocks ---------------------------------------------------
  // A comment block has exactly 3 children: header, body, social bar. They are
  // resolved first because the post card is defined as the part of the page
  // that holds none of them.
  const blocks = boxes
    .map(box => ({ box, block: ownerOf(box) }))
    .filter(p => p.block && p.block.children.length === 3);

  // --- post -------------------------------------------------------------
  // The post body is the text box that is not a comment. Its card is the
  // outermost ancestor still free of comment blocks: a structural definition,
  // so it holds whatever the author is (member, company or showcase page).
  const postBox = boxes.find(b => !blocks.some(p => p.box === b)) || null;
  let postCard = postBox;
  if (postCard) {
    while (postCard.parentElement && postCard.parentElement !== document.body
      && !blocks.some(p => postCard.parentElement.contains(p.block))) {
      postCard = postCard.parentElement;
    }
  }
  const postText = postBox ? clean(postBox) : '';
  const postLink = postCard && postBox ? actorLink(postCard, postBox) : null;
  const postAuthor = name(postLink);
  // Header leaves: everything in the card outside the body, minus the author
  // name, the degree markers and the "Post nel feed" a11y label that opens it.
  // Text nodes, not leaf elements: the timestamp shares its box with a
  // visibility icon, so it is not a leaf of its own. Only what comes before the
  // body counts - after it sit the translation toggle and the counters bar,
  // whose numbers would pass for a timestamp. Button labels ("Segui") are
  // dropped because they are UI, and the first node is the card's accessibility
  // heading ("Post nel feed").
  const postLeaves = (() => {
    if (!postCard || !postBox) return [];
    const w = document.createTreeWalker(postCard, NodeFilter.SHOW_TEXT);
    const out = [];
    for (let n = w.nextNode(); n; n = w.nextNode()) {
      const t = (n.textContent || '').replace(NB, ' ').trim();
      if (!t) continue;
      if (postBox.contains(n.parentElement)) break;
      out.push({ t, ui: !!n.parentElement.closest('button, [role="button"]') });
    }
    return out.slice(1)
      .filter(x => !x.ui).map(x => x.t)
      .filter(t => t !== postAuthor && !DEGREE.test(t) && !/^[•·]$/.test(t)
        && !(postAuthor && t.startsWith(postAuthor)));
  })();
  // The timestamp is short and carries a digit ("1g", "1 settimana"); the
  // headline is the longest of what is left, and is simply absent on the posts
  // of company and showcase pages. Both rules avoid UI text, which would tie
  // the extractor to the interface language.
  const postTime = (postLeaves.filter(x => x.length <= 30 && /\d/.test(x)).pop() || '')
    .replace(/\s*[•·]\s*$/, '').trim();
  const postHeadline = postLeaves
    .filter(x => x !== postTime && !x.startsWith(postTime))
    .sort((a, b) => b.length - a.length)[0] || '';

  // Social bar: numeric buttons in DOM order are reactions, comments, reposts.
  // Their aria-labels would be sturdier but are written in the UI language.
  const declared = (() => {
    if (!postCard) return '';
    const nums = [...postCard.querySelectorAll('button, [role="button"]')]
      .map(b => (b.innerText || '').trim())
      .filter(t => /^[\d.,\s]+$/.test(t) && /\d/.test(t));
    return (nums[1] || '').replace(/\s+/g, '');
  })();

  // --- comments ---------------------------------------------------------
  // Replies are no longer nested in the DOM: they sit at the same depth as
  // top-level comments and differ only by horizontal indent. Geometric, so it
  // does not depend on the UI language, but it does depend on the layout.
  const cblocks = blocks.filter(p => p.box !== postBox);
  const lefts = cblocks.map(p => Math.round(p.block.getBoundingClientRect().left));
  const baseLeft = lefts.length ? Math.min(...lefts) : 0;

  const comments = cblocks.map((p, i) => {
    const header = p.block.children[0];
    const bar = p.block.children[2];
    const link = actorLink(p.block, p.box);
    const author = name(link);
    const headline = (() => {
      if (!link) return '';
      const l = lines(clean(link));
      const rest = l.slice(1).filter(x => x !== author && !/^[•·]?\s*\d+°\+?$/.test(x));
      return rest[rest.length - 1] || '';
    })();
    // First leaf of the header that is not part of the author link: the
    // relative timestamp ("9h", "(modificato) 5h").
    const time = (() => {
      const leaf = [...header.querySelectorAll('*')].find(e =>
        e.children.length === 0 && e.textContent.trim() && (!link || !link.contains(e)));
      return leaf ? leaf.textContent.replace(NB, ' ').trim() : '';
    })();
    const reactions = (() => {
      const t = (clean(bar).split('\n')[0].match(/^[\d.,]+/) || [''])[0];
      return t && t !== '0' ? t : '';
    })();
    return {
      urn: '',
      reply: lefts[i] > baseLeft + 8,
      author, headline, time, reactions,
      text: clean(p.box)
    };
  }).filter(c => c.text);

  return JSON.stringify({
    postAuthor, postHeadline, postTime, postText,
    declaredComments: declared,
    comments,
    hooks: {
      textBoxes: boxes.length,
      commentBlocks: cblocks.length,
      commentary: document.querySelectorAll('[data-sdui-anchor-id^="commentary-"]').length,
      lazyColumn: document.querySelectorAll('[data-component-type="LazyColumn"]').length
    }
  });
})()
