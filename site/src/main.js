import './style.css';
import {
  createIcons,
  Github,
  ArrowRight,
  Menu,
  Check,
  CheckCircle2,
  Scan,
  ScanText,
  Cpu,
  Calendar,
  Store,
  Tag,
  Euro,
  Download,
  Smartphone,
  ShieldCheck,
  Lock,
  Fingerprint,
  WifiOff,
  Database,
  PieChart,
  BarChart3,
  Bell,
  Gauge,
  Archive,
  RotateCcw,
  Languages,
  Sparkles,
  ExternalLink,
  FileText,
  Layers,
  Zap,
  Moon,
  KeyRound,
  Info,
} from 'lucide';

/* global __APP_VERSION__ */

document.addEventListener('DOMContentLoaded', () => {
  createIcons({
    icons: {
      Github, ArrowRight, Menu, Check, CheckCircle2, Scan, ScanText, Cpu, Calendar, Store, Tag, Euro,
      Download, Smartphone, ShieldCheck, Lock, Fingerprint, WifiOff, Database, PieChart, BarChart3, Bell,
      Gauge, Archive, RotateCcw, Languages, Sparkles, ExternalLink, FileText, Layers, Zap, Moon, KeyRound, Info,
    },
  });

  // App version from pubspec.yaml (injected at build time).
  document.querySelectorAll('[data-version]').forEach((el) => {
    el.textContent = `v${__APP_VERSION__}`;
  });
  document.querySelectorAll('[data-year]').forEach((el) => {
    el.textContent = String(new Date().getFullYear());
  });

  // Mobile menu toggle
  const mobileMenuBtn = document.getElementById('mobile-menu-btn');
  const mobileMenu = document.getElementById('mobile-menu');
  if (mobileMenuBtn && mobileMenu) {
    mobileMenuBtn.addEventListener('click', () => mobileMenu.classList.toggle('hidden'));
  }

  // Smooth scroll for anchor links
  document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener('click', function (e) {
      const targetId = this.getAttribute('href');
      if (!targetId || targetId === '#') return;
      const target = document.querySelector(targetId);
      if (!target) return;
      e.preventDefault();
      target.scrollIntoView({ behavior: 'smooth' });
      if (mobileMenu && !mobileMenu.classList.contains('hidden')) mobileMenu.classList.add('hidden');
    });
  });
});

// Live APK download counter: GitHub counts every download of a release asset
// (download_count), so the page only reads that public number. No backend,
// no cookies. Unauthenticated API calls are limited to 60 per hour per IP:
// one call a minute, and none while the tab is hidden.
const RELEASES_API = 'https://api.github.com/repos/emanuelegaliano/Receipt/releases?per_page=100';
const REFRESH_MS = 60_000;

async function fetchDownloads() {
  const res = await fetch(RELEASES_API, { headers: { Accept: 'application/vnd.github+json' } });
  if (!res.ok) throw new Error(`GitHub API ${res.status}`);
  const releases = await res.json();
  return releases
    .flatMap((r) => r.assets || [])
    .filter((a) => a.name.endsWith('.apk'))
    .reduce((sum, a) => sum + a.download_count, 0);
}

function animateCount(el, from, to) {
  const format = (n) => n.toLocaleString('en-US');
  if (from === null || from === to || window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
    el.textContent = format(to);
    return;
  }
  const start = performance.now();
  const duration = 900;
  const step = (now) => {
    const t = Math.min(1, (now - start) / duration);
    const eased = 1 - (1 - t) ** 3;
    el.textContent = format(Math.round(from + (to - from) * eased));
    if (t < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

function startDownloadCounter() {
  const el = document.getElementById('download-count');
  const note = document.getElementById('download-note');
  const ping = document.getElementById('live-ping');
  if (!el) return;
  let last = null;
  const refresh = async () => {
    if (document.hidden) return;
    try {
      const total = await fetchDownloads();
      animateCount(el, last, total);
      last = total;
      ping?.classList.remove('hidden');
    } catch {
      // Rate limit or offline: keep the last number and try again later.
      ping?.classList.add('hidden');
      if (last === null && note) note.textContent = 'Counter temporarily unavailable, see the releases on GitHub.';
    }
  };
  refresh();
  setInterval(refresh, REFRESH_MS);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });
}

document.addEventListener('DOMContentLoaded', startDownloadCounter);
