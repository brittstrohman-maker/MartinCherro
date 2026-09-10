class CartDrawer extends HTMLElement {
  constructor() {
    super();

    this.addEventListener('keyup', (evt) => evt.code === 'Escape' && this.close());
    this.querySelector('#CartDrawer-Overlay').addEventListener('click', this.close.bind(this));
    this.setHeaderCartIconAccessibility();

    // Event delegation for upsell quick-add buttons
    this.addEventListener('click', (event) => {
      const quickAddButton = event.target.closest('[data-quick-add]');
      if (quickAddButton) {
        this.handleUpsellQuickAdd(quickAddButton);
      }
    });
  }

  setHeaderCartIconAccessibility() {
    const cartLink = document.querySelector('#cart-icon-bubble');
    if (!cartLink) return;

    cartLink.setAttribute('role', 'button');
    cartLink.setAttribute('aria-haspopup', 'dialog');
    cartLink.addEventListener('click', (event) => {
      event.preventDefault();
      this.open(cartLink);
    });
    cartLink.addEventListener('keydown', (event) => {
      if (event.code.toUpperCase() === 'SPACE') {
        event.preventDefault();
        this.open(cartLink);
      }
    });
  }

  open(triggeredBy) {
    if (this.classList.contains('active')) return;
    if (triggeredBy) this.setActiveElement(triggeredBy);
    const cartDrawerNote = this.querySelector('[id^="Details-"] summary');
    if (cartDrawerNote && !cartDrawerNote.hasAttribute('role')) this.setSummaryAccessibility(cartDrawerNote);
    // here the animation doesn't seem to always get triggered. A timeout seem to help
    setTimeout(() => {
      this.classList.add('animate', 'active');
    });

    this.addEventListener(
      'transitionend',
      () => {
        const containerToTrapFocusOn = this.classList.contains('is-empty')
          ? this.querySelector('.drawer__inner-empty')
          : document.getElementById('CartDrawer');
        const focusElement = this.querySelector('.drawer__inner') || this.querySelector('.drawer__close');
        trapFocus(containerToTrapFocusOn, focusElement);
      },
      { once: true },
    );

    document.body.classList.add('overflow-hidden');

    // cart-drawer-items is a CartItems subclass that extends createViewEventElement.
    // Its `view-event-trigger="manual"` skips auto-dispatch on connect; we fire
    // it here when the drawer opens, with `context: 'dialog'` from the payload attribute.
    this.querySelector('cart-drawer-items')?.dispatchViewEvent();
  }

  close() {
    this.classList.remove('active');
    removeTrapFocus(this.activeElement);
    document.body.classList.remove('overflow-hidden');
  }

  setSummaryAccessibility(cartDrawerNote) {
    cartDrawerNote.setAttribute('role', 'button');
    cartDrawerNote.setAttribute('aria-expanded', 'false');

    if (cartDrawerNote.nextElementSibling.getAttribute('id')) {
      cartDrawerNote.setAttribute('aria-controls', cartDrawerNote.nextElementSibling.id);
    }

    cartDrawerNote.addEventListener('click', (event) => {
      event.currentTarget.setAttribute('aria-expanded', !event.currentTarget.closest('details').hasAttribute('open'));
    });

    cartDrawerNote.parentElement.addEventListener('keyup', onKeyUpEscape);
  }

  handleUpsellQuickAdd(button) {
    const variantId = button.dataset.variantId;
    if (!variantId || button.getAttribute('aria-disabled') === 'true') return;

    button.setAttribute('aria-disabled', 'true');
    button.classList.add('loading');
    const spinner = button.querySelector('.loading__spinner');
    if (spinner) spinner.classList.remove('hidden');

    const sectionsToRender = this.getSectionsToRender().map((section) => section.id);
    const formData = new FormData();
    formData.append('id', variantId);
    formData.append('quantity', '1');
    formData.append('sections', sectionsToRender.join(','));
    formData.append('sections_url', window.location.pathname);

    const addUrl = (window.routes && window.routes.cart_add_url) ? window.routes.cart_add_url : '/cart/add';

    fetch(addUrl, {
      method: 'POST',
      headers: {
        'X-Requested-With': 'XMLHttpRequest',
        Accept: 'application/json',
      },
      body: formData,
    })
      .then((response) => response.json())
      .then((response) => {
        if (response.status) {
          console.error(response.description || response.message);
          return;
        }
        this.renderContents(response);
        if (typeof publish !== 'undefined' && typeof PUB_SUB_EVENTS !== 'undefined') {
          publish(PUB_SUB_EVENTS.cartUpdate, { source: 'cart-drawer-upsell', cartData: response });
        }
      })
      .catch((error) => {
        console.error('Error adding upsell item to cart:', error);
      })
      .finally(() => {
        button.removeAttribute('aria-disabled');
        button.classList.remove('loading');
        if (spinner) spinner.classList.add('hidden');
      });
  }

  renderContents(parsedState) {
    this.querySelector('.drawer__inner').classList.contains('is-empty') &&
      this.querySelector('.drawer__inner').classList.remove('is-empty');
    this.productId = parsedState.id;
    this.getSectionsToRender().forEach((section) => {
      const sectionElement = section.selector
        ? document.querySelector(section.selector)
        : document.getElementById(section.id);

      if (!sectionElement) return;
      sectionElement.innerHTML = this.getSectionInnerHTML(parsedState.sections[section.id], section.selector);
    });

    setTimeout(() => {
      this.querySelector('#CartDrawer-Overlay').addEventListener('click', this.close.bind(this));
      this.open();
    });
  }

  getSectionInnerHTML(html, selector = '.shopify-section') {
    return new DOMParser().parseFromString(html, 'text/html').querySelector(selector).innerHTML;
  }

  getSectionsToRender() {
    return [
      {
        id: 'cart-drawer',
        selector: '#CartDrawer',
      },
      {
        id: 'cart-icon-bubble',
      },
    ];
  }

  getSectionDOM(html, selector = '.shopify-section') {
    return new DOMParser().parseFromString(html, 'text/html').querySelector(selector);
  }

  setActiveElement(element) {
    this.activeElement = element;
  }
}

customElements.define('cart-drawer', CartDrawer);

class CartDrawerItems extends CartItems {
  getSectionsToRender() {
    return [
      {
        id: 'CartDrawer',
        section: 'cart-drawer',
        selector: '.drawer__inner',
      },
      {
        id: 'cart-icon-bubble',
        section: 'cart-icon-bubble',
        selector: '.shopify-section',
      },
    ];
  }
}

customElements.define('cart-drawer-items', CartDrawerItems);
