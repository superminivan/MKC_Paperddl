<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { fetchCategories, fetchConferences } from "./services/api";
import { currentUser, loadCurrentUser, logout } from "./services/auth";
import type { Category, Conference, ConferenceQuery } from "./types/conference";
import ConferenceCard from "./components/ConferenceCard.vue";


const categories = ref<Category[]>([]);
const conferences = ref<Conference[]>([]);
const query = ref<ConferenceQuery>({
  sub: [] as string[],
  q: ""
});
const loading = ref(false);
const route = useRoute();
const router = useRouter();
const isHome = computed(() => route.name === "home");

function goLogin() {
  router.push("/login");
}

function goHome() {
  router.push("/");
}

function scrollToTop() {
  window.scrollTo({
    top: 0,
    behavior: "smooth"
  });
}

async function handleLogout() {
  await logout();
  userMenuOpen.value = false;
  router.push("/");
}

type RankValue = "any" | "A*" | "A" | "B" | "C" | "N";

const ccfRank = ref<Exclude<RankValue, "A*">>("any");
const coreRank = ref<RankValue>("any");
const thcplRank = ref<Exclude<RankValue, "A*">>("any");
const yearsSelected = ref<number[]>([]);
const userMenuOpen = ref(false);

const heroTitle = ref("快速找到合适的投稿目标");

const availableYears = computed(() => {
  const years = new Set<number>();
  for (const conf of conferences.value) {
    const anyConf = conf as any;
    const y = Number(anyConf?.displayYear ?? conf.confs?.[0]?.year);
    if (Number.isFinite(y)) years.add(y);
  }
  return Array.from(years).sort((a, b) => b - a);
});

function getRank(conf: Conference, system: "ccf" | "core" | "thcpl"): string {
  const rank = conf.rank || ({} as any);
  if (system === "ccf") return (rank as any).ccf || "N";
  if (system === "core") return (rank as any).core || "N";
  return (rank as any).thcpl || (rank as any).thc || "N";
}

const ccfRankOptions = [
  { value: "any", label: "All" },
  { value: "A", label: "A" },
  { value: "B", label: "B" },
  { value: "C", label: "C" },
  { value: "N", label: "Non" }
] as const;

const coreRankOptions = [
  { value: "any", label: "All" },
  { value: "A*", label: "A*" },
  { value: "A", label: "A" },
  { value: "B", label: "B" },
  { value: "C", label: "C" },
  { value: "N", label: "Non" }
] as const;

const thcplRankOptions = [
  { value: "any", label: "All" },
  { value: "A", label: "A" },
  { value: "B", label: "B" },
  { value: "C", label: "C" },
  { value: "N", label: "Non" }
] as const;

const visibleConferences = computed(() => {
  const selectedYears = new Set(yearsSelected.value);
  return conferences.value.filter((conf) => {
    if (selectedYears.size) {
      const anyConf = conf as any;
      const year = Number(anyConf?.displayYear ?? conf.confs?.[0]?.year);
      if (!Number.isFinite(year) || !selectedYears.has(year)) return false;
    }

    if (ccfRank.value !== "any") {
      const value = getRank(conf, "ccf");
      if ((value || "N") !== ccfRank.value) return false;
    }

    if (coreRank.value !== "any") {
      const value = getRank(conf, "core");
      if ((value || "N") !== coreRank.value) return false;
    }

    if (thcplRank.value !== "any") {
      const value = getRank(conf, "thcpl");
      if ((value || "N") !== thcplRank.value) return false;
    }

    return true;
  });
});

const loadData = async () => {
  loading.value = true;
  try {
    const [cats, confs] = await Promise.all([
      fetchCategories(),
      fetchConferences(query.value)
    ]);
    categories.value = cats;
    const nowMs = Date.now();
    const parseConfDeadline = (conf: Conference) => {
      const candidate = conf.nextDeadline || conf.confs?.[0]?.timeline?.[0]?.deadline;
      if (!candidate || candidate.toUpperCase() === "TBD") return null;
      const parsed = Date.parse(candidate.replace(" ", "T"));
      return Number.isNaN(parsed) ? null : parsed;
    };
    const isExpired = (deadline: number | null) => deadline !== null && deadline <= nowMs;
    const isUrgent = (deadline: number | null, expired: boolean) => {
      if (deadline === null || expired) return false;
      const diff = deadline - nowMs;
      return diff > 0 && diff < 24 * 60 * 60 * 1000;
    };
    const expandedConfs = confs.flatMap((conf) => {
      if (!conf.confs || conf.confs.length === 0) {
        return [conf];
      }
      return conf.confs.map((edition) => {
        const editionDeadline = edition.timeline?.[0]?.deadline || conf.nextDeadline;
        return {
          ...conf,
          confs: [edition],
          nextDeadline: editionDeadline,
          edition,
          displayYear: edition.year
        } as Conference;
      });
    });
    conferences.value = expandedConfs
      .slice()
      .sort((a: Conference, b: Conference) => {
        const aTime = parseConfDeadline(a);
        const bTime = parseConfDeadline(b);
        const aExpired = isExpired(aTime);
        const bExpired = isExpired(bTime);
        if (aExpired && !bExpired) return 1;
        if (!aExpired && bExpired) return -1;
        const aUrgent = isUrgent(aTime, aExpired);
        const bUrgent = isUrgent(bTime, bExpired);
        if (aUrgent && !bUrgent) return -1;
        if (!aUrgent && bUrgent) return 1;
        if (aTime === null && bTime === null) return 0;
        if (aTime === null) return 1;
        if (bTime === null) return -1;
        return aTime - bTime;
      });
  } catch (e) {
    console.error("Failed to fetch data:", e);
  } finally {
    loading.value = false;
  }
};

function handleSearchInput(e: Event) {
  const target = e.target as HTMLInputElement;
  query.value.q = target.value;
}

function handleSearchSubmit() {
  loadData();
}

function toggleYear(year: number) {
  const set = new Set(yearsSelected.value);
  if (set.has(year)) set.delete(year);
  else set.add(year);
  yearsSelected.value = Array.from(set).sort((a, b) => b - a);
}

function clearFilters() {
  query.value.sub = [];
  yearsSelected.value = [];
  ccfRank.value = "any";
  coreRank.value = "any";
  thcplRank.value = "any";
}

function toggleUserMenu() {
  userMenuOpen.value = !userMenuOpen.value;
}

function showFavoritesPlaceholder() {
  userMenuOpen.value = false;
  window.alert("后续实现");
}

function handleDocumentClick(event: MouseEvent) {
  const target = event.target as HTMLElement | null;
  if (!target?.closest(".user-menu")) {
    userMenuOpen.value = false;
  }
}

onMounted(() => {
  loadCurrentUser().catch(() => {
    // Auth state is optional on public pages.
  });
  loadData();
  document.addEventListener("click", handleDocumentClick);
});

onBeforeUnmount(() => {
  document.removeEventListener("click", handleDocumentClick);
});

watch(
  query,
  () => {
    loadData();
  },
  { deep: true }
);
</script>

<template>
  <div class="app-shell">
    <template v-if="isHome">
      <header class="top-nav">
        <div class="top-nav__inner">
          <button class="brand-mark" type="button" @click="goHome">
            <span class="brand-mark__title">PaperDDL</span>
            <span class="brand-mark__subtitle">Conference Deadlines</span>
          </button>

          <div class="top-nav__actions">
            <button
              v-if="!currentUser"
              class="nav-ghost-btn"
              type="button"
              @click="goLogin"
            >
              &#30331;&#24405;
            </button>

            <div v-else class="user-menu">
              <button class="user-menu__trigger" type="button" @click.stop="toggleUserMenu">
                <span class="user-menu__name">{{ currentUser.username }}</span>
                <span class="user-menu__caret">{{ userMenuOpen ? "^" : "v" }}</span>
              </button>
              <div v-if="userMenuOpen" class="user-menu__panel">
                <button class="user-menu__item" type="button" @click="showFavoritesPlaceholder">
                  &#25910;&#34255;&#20250;&#35758;
                </button>
                <button class="user-menu__item" type="button" @click="handleLogout">
                  &#36864;&#20986;&#30331;&#24405;
                </button>
              </div>
            </div>
          </div>
        </div>
      </header>

      <main class="home-page">
        <section class="hero-banner">
          <div class="hero-banner__overlay">
            <p class="hero-banner__eyebrow">PaperDDL</p>
            <h1 class="hero-banner__title">{{ heroTitle }}</h1>
          </div>
        </section>

        <section class="search-panel">
          <form class="search-panel__form" @submit.prevent="handleSearchSubmit">
            <input
              class="search-panel__input"
              type="text"
              :value="query.q"
              placeholder="&#25628;&#32034;&#20250;&#35758;&#21517;&#31216;&#12289;&#31616;&#31216;&#25110;&#20851;&#38190;&#35789;"
              @input="handleSearchInput"
            />
            <button class="search-panel__button" type="submit">&#25628;&#32034;</button>
          </form>
        </section>

        <section class="content-layout">
          <aside class="filter-sidebar">
            <div class="filter-sidebar__header">
              <h2>&#31579;&#36873;&#26465;&#20214;</h2>
              <button class="filter-clear-btn" type="button" @click="clearFilters">
                &#28165;&#38500;
              </button>
            </div>

            <div class="filter-group">
              <div class="filter-group__title">&#30740;&#31350;&#26041;&#21521;</div>
              <div class="chip-list">
                <label v-for="cat in categories" :key="cat.sub" class="chip-check">
                  <input v-model="query.sub" type="checkbox" :value="cat.sub" />
                  <span>{{ cat.name }}</span>
                </label>
              </div>
            </div>

            <div v-if="availableYears.length" class="filter-group">
              <div class="filter-group__title">&#24180;&#20221;</div>
              <div class="chip-list chip-list--compact">
                <label v-for="y in availableYears" :key="y" class="chip-check">
                  <input
                    type="checkbox"
                    :checked="yearsSelected.includes(y)"
                    @change="toggleYear(y)"
                  />
                  <span>{{ y }}</span>
                </label>
              </div>
            </div>

            <div class="filter-group">
              <div class="filter-group__title">CCF</div>
              <select v-model="ccfRank" class="filter-select" aria-label="CCF rank">
                <option v-for="opt in ccfRankOptions" :key="opt.value" :value="opt.value">
                  {{ opt.label }}
                </option>
              </select>
            </div>

            <div class="filter-group">
              <div class="filter-group__title">CORE</div>
              <select v-model="coreRank" class="filter-select" aria-label="CORE rank">
                <option v-for="opt in coreRankOptions" :key="opt.value" :value="opt.value">
                  {{ opt.label }}
                </option>
              </select>
            </div>

            <div class="filter-group">
              <div class="filter-group__title">THCPL</div>
              <select v-model="thcplRank" class="filter-select" aria-label="THCPL rank">
                <option v-for="opt in thcplRankOptions" :key="opt.value" :value="opt.value">
                  {{ opt.label }}
                </option>
              </select>
            </div>
          </aside>

          <section class="results-panel">
            <div class="results-panel__header">
              <div>
                <p class="results-panel__caption">&#20026;&#20320;&#25512;&#33616;</p>
                <h2 class="results-panel__title">
                  &#20026;&#20320;&#25512;&#33616;&#65288;{{ visibleConferences.length }}&#65289;
                </h2>
              </div>
            </div>

            <div v-if="loading" class="state-panel">&#21152;&#36733;&#20013;...</div>
            <div v-else-if="visibleConferences.length === 0" class="state-panel">
              &#26410;&#25214;&#21040;&#30456;&#20851;&#20250;&#35758;&#12290;&#35831;&#23581;&#35797;&#35843;&#25972;&#31579;&#36873;&#26465;&#20214;&#25110;&#25628;&#32034;&#20851;&#38190;&#35789;&#12290;
            </div>
            <div v-else class="conference-list">
              <ConferenceCard
                v-for="conf in visibleConferences"
                :key="`${conf.title}-${(conf as any).displayYear || conf.confs?.[0]?.year || ''}`"
                :conference="conf"
                :highlight="query.q || ''"
              />
            </div>
          </section>
        </section>
      </main>
      <button
        class="back-to-top"
        type="button"
        @click="scrollToTop"
        aria-label="返回顶部"
        title="返回顶部"
      >
        <svg
          class="back-to-top__icon"
          viewBox="0 0 24 24"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          aria-hidden="true"
        >
          <path
            d="M12 19V5"
            stroke="currentColor"
            stroke-width="2.2"
            stroke-linecap="round"
          />
          <path
            d="M6 11L12 5L18 11"
            stroke="currentColor"
            stroke-width="2.2"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </button>
    </template>

    <RouterView v-else v-slot="{ Component }">
      <div :class="{ 'admin-route-shell': route.name === 'admin' }">
        <component :is="Component" @close="goHome" />
      </div>
    </RouterView>
  </div>
</template>
