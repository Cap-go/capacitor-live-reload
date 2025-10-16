import './style.css';
import { LiveReload } from '@capgo/capacitor-live-reload';

const plugin = LiveReload;
const eventsBox = document.getElementById('plugin-output');

const actions = [
  {
    id: 'configure',
    label: 'Configure server',
    description: 'Save the remote dev server URL and optional WebSocket settings.',
    inputs: [
      { name: 'url', label: 'Server URL', type: 'text', value: 'http://localhost:5173' },
      { name: 'websocketPath', label: 'WebSocket path', type: 'text', value: '/capgo-livereload' },
      { name: 'autoReconnect', label: 'Auto reconnect', type: 'checkbox', value: true },
      { name: 'reconnectInterval', label: 'Reconnect interval (ms)', type: 'number', value: 2000 },
    ],
    run: async (values) => {
      const status = await plugin.configureServer({
        url: values.url,
        websocketPath: values.websocketPath,
        autoReconnect: values.autoReconnect,
        reconnectInterval: values.reconnectInterval ? Number(values.reconnectInterval) : undefined,
      });
      return status;
    },
  },
  {
    id: 'connect',
    label: 'Connect',
    description: 'Open the WebSocket connection to the configured server.',
    run: async () => {
      const status = await plugin.connect();
      return status;
    },
  },
  {
    id: 'disconnect',
    label: 'Disconnect',
    description: 'Close the WebSocket connection.',
    run: async () => {
      const status = await plugin.disconnect();
      return status;
    },
  },
  {
    id: 'status',
    label: 'Get status',
    description: 'Read the current connection status.',
    run: async () => {
      const status = await plugin.getStatus();
      return status;
    },
  },
  {
    id: 'reload',
    label: 'Force reload',
    description: 'Trigger a full reload of the Capacitor WebView.',
    run: async () => {
      await plugin.reload();
      return 'Reload requested';
    },
  },
  {
    id: 'simulate-file',
    label: 'Simulate file update',
    description: 'Invoke reloadFile with a fake path to test native handling.',
    inputs: [
      { name: 'path', label: 'File path', type: 'text', value: '/src/main.ts' },
      { name: 'hash', label: 'Hash (optional)', type: 'text', value: '' },
    ],
    run: async (values) => {
      await plugin.reloadFile({ path: values.path, hash: values.hash || undefined });
      return 'File reload requested';
    },
  },
];

const actionSelect = document.getElementById('action-select');
const formContainer = document.getElementById('action-form');
const descriptionBox = document.getElementById('action-description');
const runButton = document.getElementById('run-action');
const quickConnectButton = document.getElementById('quick-connect');

function buildForm(action) {
    formContainer.innerHTML = '';
    if (!action.inputs || !action.inputs.length) {
        const note = document.createElement('p');
        note.className = 'no-input-note';
        note.textContent = 'This action does not require any inputs.';
        formContainer.appendChild(note);
        return;
    }
    action.inputs.forEach((input) => {
        const fieldWrapper = document.createElement('div');
        fieldWrapper.className = input.type === 'checkbox' ? 'form-field inline' : 'form-field';

        const label = document.createElement('label');
        label.textContent = input.label;
        label.htmlFor = `field-${input.name}`;

        let field;
        switch (input.type) {
            case 'textarea': {
                field = document.createElement('textarea');
                field.rows = input.rows || 4;
                if (input.value) field.value = input.value;
                break;
            }
            case 'select': {
                field = document.createElement('select');
                (input.options || []).forEach((option) => {
                    const opt = document.createElement('option');
                    opt.value = option.value;
                    opt.textContent = option.label;
                    if (input.value !== undefined && option.value === input.value) {
                        opt.selected = true;
                    }
                    field.appendChild(opt);
                });
                break;
            }
            case 'checkbox': {
                field = document.createElement('input');
                field.type = 'checkbox';
                field.checked = Boolean(input.value);
                break;
            }
            case 'number': {
                field = document.createElement('input');
                field.type = 'number';
                if (input.value !== undefined && input.value !== null) {
                    field.value = String(input.value);
                }
                break;
            }
            default: {
                field = document.createElement('input');
                field.type = input.type || 'text';
                if (input.value !== undefined && input.value !== null) {
                    field.value = String(input.value);
                }
            }
        }

        field.id = `field-${input.name}`;
        field.name = input.name;
        field.dataset.type = input.type || 'text';

        if (input.placeholder && input.type !== 'checkbox') {
            field.placeholder = input.placeholder;
        }

        if (input.type === 'checkbox') {
            fieldWrapper.appendChild(field);
            fieldWrapper.appendChild(label);
        } else {
            fieldWrapper.appendChild(label);
            fieldWrapper.appendChild(field);
        }

        formContainer.appendChild(fieldWrapper);
    });
}

function getFormValues(action) {
    const values = {};
    (action.inputs || []).forEach((input) => {
        const field = document.getElementById(`field-${input.name}`);
        if (!field) return;
        switch (input.type) {
            case 'number':
                values[input.name] = field.value === '' ? null : Number(field.value);
                break;
            case 'checkbox':
                values[input.name] = field.checked;
                break;
            default:
                values[input.name] = field.value;
        }
    });
    return values;
}

function setAction(action) {
    descriptionBox.textContent = action.description || '';
    buildForm(action);
    eventsBox.textContent = 'Ready to run the selected action.';
}

function populateActions() {
    actionSelect.innerHTML = '';
    actions.forEach((action) => {
        const option = document.createElement('option');
        option.value = action.id;
        option.textContent = action.label;
        actionSelect.appendChild(option);
    });
    setAction(actions[0]);
}

actionSelect.addEventListener('change', () => {
    const action = actions.find((item) => item.id === actionSelect.value);
    if (action) {
        setAction(action);
    }
});

runButton.addEventListener('click', async () => {
    const action = actions.find((item) => item.id === actionSelect.value);
    if (!action) return;
    const values = getFormValues(action);
    try {
        const result = await action.run(values);
        if (result === undefined) {
            eventsBox.textContent = 'Action completed.';
        } else if (typeof result === 'string') {
            eventsBox.textContent = result;
        } else {
            eventsBox.textContent = JSON.stringify(result, null, 2);
        }
    } catch (error) {
        eventsBox.textContent = `Error: ${error?.message ?? error}`;
    }
});

function appendLog(prefix, payload) {
    const existing = eventsBox.textContent || '';
    const timestamp = new Date().toISOString();
    const line = `${timestamp} [${prefix}] ${typeof payload === 'string' ? payload : JSON.stringify(payload)}\n`;
    eventsBox.textContent = `${line}${existing}`.slice(0, 5000);
}

(async () => {
    try {
        await plugin.addListener('reloadEvent', (event) => appendLog('event', event));
        await plugin.addListener('statusChange', (status) => appendLog('status', status));
    } catch (error) {
        appendLog('listener-error', error?.message ?? String(error));
    }
})();

populateActions();

quickConnectButton?.addEventListener('click', async () => {
    try {
        appendLog('quick-connect', 'Configuring live reload for http://localhost:5173');
        await plugin.configureServer({
            url: 'http://localhost:5173',
            websocketPath: '/capgo-livereload',
            autoReconnect: true,
            reconnectInterval: 2000,
        });
        const status = await plugin.connect();
        appendLog('quick-connect', status);
    } catch (error) {
        appendLog('quick-connect-error', error?.message ?? String(error));
    }
});
