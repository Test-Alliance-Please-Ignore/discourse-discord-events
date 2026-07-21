export default function () {
  this.route("discord-events", function () {
    this.route("show", { path: "/:id" });
  });
}
