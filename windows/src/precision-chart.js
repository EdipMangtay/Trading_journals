import Chart from 'chart.js/auto';
import { nearestPoint } from '../shared/workstation.mjs';

export const motionAllowed = preferences => preferences.animations && !matchMedia('(prefers-reduced-motion: reduce)').matches;

export function precisionChart(canvas, { points, datasets, format, describe, tick, duration = 0, range = {} }) {
  if (!canvas || !points.length) return null;
  const parent = canvas.parentElement;
  const style = getComputedStyle(document.documentElement);
  const muted = style.getPropertyValue('--muted').trim();
  const color = datasets.at(-1).borderColor;
  const first = points[0].date, last = points.at(-1).date;
  const pad = Math.max((last - first) * .025, first > 1e9 ? 60000 : .1);
  let progress = duration ? 0 : 1, frame;
  const mask = {
    id: 'edgeReveal',
    beforeDatasetsDraw({ ctx, chartArea: a }) {
      ctx.save();
      ctx.beginPath();
      ctx.rect(a.left - 1, a.top - 1, (a.width + 2) * progress, a.height + 2);
      ctx.clip();
    },
    afterDatasetsDraw({ ctx }) { ctx.restore(); }
  };
  const chart = new Chart(canvas, {
    type: 'line',
    data: { datasets: datasets.map(d => ({ pointRadius: 0, borderWidth: 2.4, tension: 0, ...d })) },
    plugins: [mask],
    options: {
      responsive: true, maintainAspectRatio: false, parsing: false, animation: false, events: [],
      plugins: { legend: { display: false }, tooltip: { enabled: false } },
      scales: {
        x: { type: 'linear', min: first - pad, max: last + pad, grid: { display: false }, border: { display: false }, ticks: { maxTicksLimit: 6, maxRotation: 0, callback: tick } },
        y: { position: 'right', beginAtZero: true, grid: { color: muted + '22' }, border: { display: false }, ticks: { maxTicksLimit: 6, callback: value => format(value, true) }, ...range }
      }
    }
  });
  if (duration) {
    const start = performance.now();
    const draw = now => {
      const t = Math.min(1, (now - start) / duration);
      progress = t * t * (3 - 2 * t);
      chart.draw();
      if (t < 1) frame = requestAnimationFrame(draw);
    };
    frame = requestAnimationFrame(draw);
  }
  const overlay = document.createElement('div');
  overlay.className = 'plot-inspector';
  overlay.hidden = true;
  overlay.innerHTML = '<i class="cross-x"></i><i class="cross-y"></i><i class="cross-point"></i><div class="plot-tooltip"></div>';
  parent.append(overlay);
  const tooltip = overlay.lastElementChild;
  const controls = document.createElement('div');
  controls.className = 'plot-controls';
  controls.innerHTML = '<button type="button" aria-label="Önceki grafik noktası">‹</button><button type="button" aria-label="Sonraki grafik noktası">›</button><output aria-live="polite"></output>';
  parent.before(controls);
  const output = controls.lastElementChild;
  output.textContent = format(points.at(-1).value);
  let locked = null, hovered = null;
  function inspect(index, keyboard = false) {
    const point = points[index];
    if (!point) { overlay.hidden = true; return; }
    const a = chart.chartArea, x = chart.scales.x.getPixelForValue(point.date), y = chart.scales.y.getPixelForValue(point.value);
    const lines = describe(point);
    overlay.hidden = false;
    overlay.style.setProperty('--cross-color', color);
    Object.assign(overlay.children[0].style, { left: x + 'px', top: a.top + 'px', height: a.height + 'px' });
    Object.assign(overlay.children[1].style, { left: a.left + 'px', top: y + 'px', width: a.width + 'px' });
    Object.assign(overlay.children[2].style, { left: x + 'px', top: y + 'px' });
    tooltip.replaceChildren(...lines.map((line, i) => {
      const element = document.createElement(i ? 'span' : 'strong');
      element.textContent = line;
      return element;
    }));
    tooltip.style.maxWidth = Math.max(72, a.width - 12) + 'px';
    const w = tooltip.offsetWidth, h = tooltip.offsetHeight;
    const left = x + w + 16 < a.right ? x + 12 : x - w - 12;
    tooltip.style.left = Math.max(a.left + 4, Math.min(left, a.right - w - 4)) + 'px';
    tooltip.style.top = Math.max(a.top + 4, Math.min(y - h - 10, a.bottom - h - 4)) + 'px';
    if (keyboard) output.textContent = lines.join(' · ');
  }
  function step(direction) {
    locked = Math.max(0, Math.min(points.length - 1, (locked ?? points.length - 1) + direction));
    inspect(locked, true);
  }
  controls.children[0].onclick = () => step(-1);
  controls.children[1].onclick = () => step(1);
  const open = index => {
    const id = points[index]?.trade?.id;
    if (id) document.dispatchEvent(new CustomEvent('edge:trade', { detail: id }));
  };
  canvas.tabIndex = 0;
  canvas.onkeydown = event => {
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
      event.preventDefault();
      step(event.key === 'ArrowLeft' ? -1 : 1);
    } else if (event.key === 'Enter') open(locked);
  };
  function indexAt(event) {
    const bounds = canvas.getBoundingClientRect(), a = chart.chartArea;
    const x = (event.clientX - bounds.left) * chart.width / bounds.width;
    const y = (event.clientY - bounds.top) * chart.height / bounds.height;
    return x >= a.left && x <= a.right && y >= a.top && y <= a.bottom
      ? nearestPoint(points, chart.scales.x.getValueForPixel(x)) : -1;
  }
  canvas.onpointermove = event => {
    const index = indexAt(event);
    if (index === hovered) return;
    hovered = index;
    inspect(index >= 0 ? index : locked);
  };
  canvas.onpointerleave = () => { hovered = null; inspect(locked); };
  canvas.onclick = event => open(indexAt(event));
  return { destroy() { cancelAnimationFrame(frame); chart.destroy(); } };
}
