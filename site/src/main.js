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
