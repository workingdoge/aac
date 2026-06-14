type HtmxRoot = Document | DocumentFragment | ShadowRoot | HTMLElement;

type HtmxLike = {
  process: (root?: HtmxRoot) => void;
};

declare global {
  interface Window {
    htmx?: HtmxLike;
  }
}

function process(root: HtmxRoot = document) {
  const forms = Array.from(root.querySelectorAll?.('form[hx-post]') ?? []);
  for (const form of forms) bindForm(form as HTMLFormElement, root);
}

function bindForm(form: HTMLFormElement, root: HtmxRoot) {
  if (form.dataset.aacHtmxBound === 'true') return;
  form.dataset.aacHtmxBound = 'true';
  form.addEventListener('submit', (event) => {
    event.preventDefault();
    void submitForm(form, root);
  });
}

async function submitForm(form: HTMLFormElement, root: HtmxRoot) {
  const url = form.getAttribute('hx-post');
  if (!url) return;
  const target = resolveTarget(root, form.getAttribute('hx-target'));
  const body = new URLSearchParams();
  for (const [key, value] of new FormData(form).entries()) {
    body.append(key, String(value));
  }
  form.dispatchEvent(new CustomEvent('htmx:beforeRequest', {
    bubbles: true,
    composed: true,
    detail: { form },
  }));
  let response: Response | null = null;
  let responseText = '';
  try {
    response = await fetch(url, {
      method: 'POST',
      headers: {
        'content-type': 'application/x-www-form-urlencoded;charset=UTF-8',
        'hx-request': 'true',
      },
      body,
    });
    responseText = await response.text();
    if (target) target.innerHTML = responseText;
    form.dispatchEvent(new CustomEvent('htmx:afterRequest', {
      bubbles: true,
      composed: true,
      detail: { form, response, responseText, successful: response.ok },
    }));
  } catch (error) {
    form.dispatchEvent(new CustomEvent('htmx:responseError', {
      bubbles: true,
      composed: true,
      detail: { form, response, responseText, error },
    }));
  }
}

function resolveTarget(root: HtmxRoot, selector: string | null): HTMLElement | null {
  if (!selector) return null;
  const local = root.querySelector?.(selector);
  if (local instanceof HTMLElement) return local;
  const global = document.querySelector(selector);
  return global instanceof HTMLElement ? global : null;
}

window.htmx = window.htmx ?? { process };
window.htmx.process = process;

export {};
