"""Discord bot: license panel, /key redeemer, and admin commands.

Runs in the same process as the FastAPI app (started from app.main's
lifespan) so it talks to the database directly through licensing.*.
"""
from __future__ import annotations

import logging

import discord
from discord import app_commands
from discord.ext import commands

from app import config, licensing
from app.db import SessionLocal

from .loader import build_loader

log = logging.getLogger("orbit.bot")

EMBED_COLOR = 0x5865F2
OK_COLOR = 0x00FF88
ERR_COLOR = 0xFF4444


# ── permission helper ───────────────────────────────────────────────────
def is_admin(interaction: discord.Interaction) -> bool:
    if isinstance(interaction.user, discord.Member):
        if interaction.user.guild_permissions.administrator:
            return True
        if config.ADMIN_ROLE_ID:
            role_ids = {str(r.id) for r in interaction.user.roles}
            return config.ADMIN_ROLE_ID in role_ids
    return False


def _err(msg: str) -> discord.Embed:
    return discord.Embed(title="❌ Fehler", description=msg, color=ERR_COLOR)


def _ok(title: str, msg: str) -> discord.Embed:
    return discord.Embed(title=title, description=msg, color=OK_COLOR)


# ── the persistent panel ─────────────────────────────────────────────────
class PanelView(discord.ui.View):
    """Buttons stay clickable across restarts thanks to fixed custom_ids."""

    def __init__(self) -> None:
        super().__init__(timeout=None)

    @discord.ui.button(
        label="Get Script (Public)",
        style=discord.ButtonStyle.secondary,
        emoji="🌐",
        custom_id="orbit:get:public",
    )
    async def public_button(self, interaction: discord.Interaction, _button: discord.ui.Button):
        await self._serve_public(interaction, "public")

    @discord.ui.button(
        label="Redeem Key (Premium)",
        style=discord.ButtonStyle.success,
        emoji="🔑",
        custom_id="orbit:redeem:premium",
    )
    async def redeem_button(self, interaction: discord.Interaction, _button: discord.ui.Button):
        # Open a popup where the user types their key. On submit they get the
        # loadstring loader with the key baked in — no slash command needed.
        await interaction.response.send_modal(RedeemKeyModal(tier="premium"))

    async def _serve_public(self, interaction: discord.Interaction, tier: str):
        # Public tier: hand over a ready-to-run loader using a shared public
        # key so anyone in the server can grab the free script. The HWID lock
        # still applies per machine on first use.
        loader = build_loader(key="PUBLIC", tier=tier)
        embed = _ok(
            "🌐 Public Script",
            "Kopier den Loader unten in deinen Executor und führ ihn aus.",
        )
        await interaction.response.send_message(
            embed=embed, content=f"```lua\n{loader}\n```", ephemeral=True
        )


# ── the redeem popup ─────────────────────────────────────────────────────
class RedeemKeyModal(discord.ui.Modal, title="Redeem Key"):
    """Popup with a key field. Validates the key, links it to the Discord user
    and returns the loadstring loader with the key already filled in."""

    key_input: discord.ui.TextInput = discord.ui.TextInput(
        label="Dein Lizenz-Key",
        placeholder="ORBIT-XXXXX-XXXXX-XXXXX-XXXXX",
        required=True,
        min_length=4,
        max_length=128,
    )

    def __init__(self, tier: str = "premium") -> None:
        super().__init__()
        self.tier = tier

    async def on_submit(self, interaction: discord.Interaction):
        key = str(self.key_input.value).strip().upper()
        db = SessionLocal()
        try:
            lic = licensing.link_discord(db, key, interaction.user.id)
            loader = build_loader(key=key, tier=lic.tier)
            embed = _ok(
                "✅ Key eingelöst",
                f"Tier: **{lic.tier}**\n"
                "Dein Loader steht unten — kopier ihn in deinen Executor. "
                "Beim ersten Start wird der Key an deine HWID gebunden und "
                "läuft danach nur noch auf diesem Gerät.",
            )
            await interaction.response.send_message(
                embed=embed, content=f"```lua\n{loader}\n```", ephemeral=True
            )
            log_bot = interaction.client
            if isinstance(log_bot, OrbitBot):
                await log_bot.log_event(
                    f"🔑 <@{interaction.user.id}> hat einen **{lic.tier}** key "
                    "über das Panel eingelöst."
                )
        except licensing.LicenseError as exc:
            await interaction.response.send_message(embed=_err(str(exc)), ephemeral=True)
        finally:
            db.close()


# ── the bot ──────────────────────────────────────────────────────────────
class OrbitBot(commands.Bot):
    def __init__(self) -> None:
        intents = discord.Intents.default()
        super().__init__(command_prefix="!", intents=intents)

    async def setup_hook(self) -> None:
        # Register the persistent view so old panels keep working.
        self.add_view(PanelView())
        register_commands(self)
        if config.DISCORD_GUILD_ID:
            guild = discord.Object(id=int(config.DISCORD_GUILD_ID))
            self.tree.copy_global_to(guild=guild)
            await self.tree.sync(guild=guild)
        else:
            await self.tree.sync()
        log.info("slash commands synced")

    async def on_ready(self) -> None:
        log.info("logged in as %s (%s)", self.user, self.user.id if self.user else "?")
        await self.change_presence(activity=discord.Game(name="/key • Orbit"))

    async def log_event(self, text: str) -> None:
        if not config.LOG_CHANNEL_ID:
            return
        try:
            ch = await self.fetch_channel(int(config.LOG_CHANNEL_ID))
            await ch.send(embed=discord.Embed(description=text, color=EMBED_COLOR))
        except Exception as exc:  # noqa: BLE001
            log.warning("log_event failed: %s", exc)


def register_commands(bot: OrbitBot) -> None:
    tree = bot.tree

    @tree.command(name="panel", description="Post the script panel in this channel (admin)")
    async def panel(interaction: discord.Interaction):
        if not is_admin(interaction):
            return await interaction.response.send_message(
                embed=_err("Keine Berechtigung."), ephemeral=True
            )
        embed = discord.Embed(
            title="🛰️  Orbit — Script Panel",
            description=(
                "Wähl unten dein Script.\n\n"
                "🌐 **Public** — frei für alle, direkt laden\n"
                "🔑 **Redeem Key** — Key eingeben, Loader zurückbekommen\n\n"
                "Jeder Key wird an **eine** HWID gebunden — niemand sonst kann "
                "ihn danach einlösen."
            ),
            color=EMBED_COLOR,
        )
        embed.set_footer(text="Orbit Auth")
        await interaction.channel.send(embed=embed, view=PanelView())
        await interaction.response.send_message(
            embed=_ok("✅ Panel gepostet", "Das Panel ist jetzt aktiv."),
            ephemeral=True,
        )

    @tree.command(name="key", description="Redeem your license key")
    @app_commands.describe(key="Dein Lizenz-Key")
    async def key_cmd(interaction: discord.Interaction, key: str):
        db = SessionLocal()
        try:
            lic = licensing.link_discord(db, key, interaction.user.id)
            loader = build_loader(key=key.strip().upper(), tier=lic.tier)
            embed = _ok(
                "✅ Key eingelöst",
                f"Tier: **{lic.tier}**\n"
                "Dein persönlicher Loader steht unten. Beim ersten Start wird "
                "der Key an deine HWID gebunden.",
            )
            await interaction.response.send_message(
                embed=embed, content=f"```lua\n{loader}\n```", ephemeral=True
            )
            await bot.log_event(
                f"🔑 <@{interaction.user.id}> hat einen **{lic.tier}** key eingelöst."
            )
        except licensing.LicenseError as exc:
            await interaction.response.send_message(embed=_err(str(exc)), ephemeral=True)
        finally:
            db.close()

    @tree.command(name="genkey", description="Generate license keys (admin)")
    @app_commands.describe(
        tier="Script tier (public/premium)",
        amount="How many keys",
        expires_days="Optional expiry in days",
    )
    async def genkey(
        interaction: discord.Interaction,
        tier: str = "public",
        amount: int = 1,
        expires_days: int | None = None,
    ):
        if not is_admin(interaction):
            return await interaction.response.send_message(
                embed=_err("Keine Berechtigung."), ephemeral=True
            )
        if amount < 1 or amount > 200:
            return await interaction.response.send_message(
                embed=_err("amount muss 1–200 sein."), ephemeral=True
            )
        db = SessionLocal()
        try:
            keys = licensing.create_keys(
                db, tier=tier, amount=amount, expires_days=expires_days
            )
        except licensing.LicenseError as exc:
            return await interaction.response.send_message(
                embed=_err(str(exc)), ephemeral=True
            )
        finally:
            db.close()

        body = "\n".join(f"`{k}`" for k in keys)
        embed = _ok(f"✅ {len(keys)} key(s) generiert", f"Tier: **{tier}**\n\n{body}")
        if expires_days:
            embed.set_footer(text=f"Läuft ab in {expires_days} Tagen")
        await interaction.response.send_message(embed=embed, ephemeral=True)
        await bot.log_event(
            f"🧾 <@{interaction.user.id}> hat **{len(keys)}** {tier} key(s) generiert."
        )

    @tree.command(name="resethwid", description="Reset a key's HWID lock (admin)")
    @app_commands.describe(key="Der Key, dessen HWID zurückgesetzt wird")
    async def resethwid(interaction: discord.Interaction, key: str):
        if not is_admin(interaction):
            return await interaction.response.send_message(
                embed=_err("Keine Berechtigung."), ephemeral=True
            )
        db = SessionLocal()
        try:
            licensing.reset_hwid(db, key)
            await interaction.response.send_message(
                embed=_ok("✅ HWID zurückgesetzt", "Der Key kann neu gebunden werden."),
                ephemeral=True,
            )
            await bot.log_event(f"♻️ <@{interaction.user.id}> hat eine HWID zurückgesetzt.")
        except licensing.LicenseError as exc:
            await interaction.response.send_message(embed=_err(str(exc)), ephemeral=True)
        finally:
            db.close()

    @tree.command(name="revoke", description="Revoke a key (admin)")
    @app_commands.describe(key="Der zu sperrende Key")
    async def revoke(interaction: discord.Interaction, key: str):
        if not is_admin(interaction):
            return await interaction.response.send_message(
                embed=_err("Keine Berechtigung."), ephemeral=True
            )
        db = SessionLocal()
        try:
            licensing.revoke(db, key)
            await interaction.response.send_message(
                embed=_ok("✅ Key gesperrt", "Der Key funktioniert nicht mehr."),
                ephemeral=True,
            )
            await bot.log_event(f"⛔ <@{interaction.user.id}> hat einen key gesperrt.")
        except licensing.LicenseError as exc:
            await interaction.response.send_message(embed=_err(str(exc)), ephemeral=True)
        finally:
            db.close()

    @tree.command(name="keyinfo", description="Show status of a key (admin)")
    @app_commands.describe(key="Der Key")
    async def keyinfo(interaction: discord.Interaction, key: str):
        if not is_admin(interaction):
            return await interaction.response.send_message(
                embed=_err("Keine Berechtigung."), ephemeral=True
            )
        db = SessionLocal()
        try:
            lic = licensing.get_info(db, key)
            if lic is None:
                return await interaction.response.send_message(
                    embed=_err("Key nicht gefunden."), ephemeral=True
                )
            embed = discord.Embed(title="🔎 Key Info", color=EMBED_COLOR)
            embed.add_field(name="Tier", value=lic.tier, inline=True)
            embed.add_field(name="Status", value=lic.status, inline=True)
            embed.add_field(name="Uses", value=str(lic.uses), inline=True)
            embed.add_field(
                name="HWID", value="🔒 gebunden" if lic.hwid else "🔓 frei", inline=True
            )
            embed.add_field(
                name="Discord",
                value=f"<@{lic.discord_id}>" if lic.discord_id else "—",
                inline=True,
            )
            embed.add_field(
                name="Läuft ab",
                value=lic.expires_at.strftime("%Y-%m-%d") if lic.expires_at else "nie",
                inline=True,
            )
            await interaction.response.send_message(embed=embed, ephemeral=True)
        finally:
            db.close()
