import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class DiscordEventsIndexController extends Controller {
  @tracked filter = "upcoming";
  @tracked q = "";
  @tracked sort = null;
  @tracked page = 0;
  queryParams = ["filter", "q", "sort", "page"];

  get totalPages() {
    const { total, per_page: perPage } = this.model.meta;
    return Math.max(1, Math.ceil(total / perPage));
  }

  get currentPageDisplay() {
    return this.model.meta.page + 1;
  }

  get showPagination() {
    return this.totalPages > 1;
  }

  get isFirstPage() {
    return this.model.meta.page <= 0;
  }

  get isLastPage() {
    return !this.model.meta.more;
  }

  @action
  changeFilter(filter) {
    this.filter = filter;
    this.page = 0;
  }

  @action
  search(term) {
    this.q = term;
    this.page = 0;
  }

  @action
  changeSort(sort) {
    this.sort = sort;
    this.page = 0;
  }

  @action
  previousPage() {
    this.page = Math.max(0, this.model.meta.page - 1);
  }

  @action
  nextPage() {
    if (this.model.meta.more) {
      this.page = this.model.meta.page + 1;
    }
  }
}
