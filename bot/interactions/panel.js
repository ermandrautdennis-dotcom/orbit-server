// The authentication panel: a persistent Discord embed with buttons, plus the
// modal and the ephemeral responses behind them.
//
// Every custom_id here is a static string, carrying no state and no credential.
// That is what keeps the panel usable indefinitely, including across bot
// restarts and redeploys: nothing is cached in memory, so there is no session to
// lose, and nothing in a component id can be tampered with to gain anything —
// the acting user's identity always comes from the interaction Discord signed,
// never from the component.
import {
    ActionRowBuilder, ButtonBuilder, ButtonStyle, EmbedBuilder, MessageFlags,
    ModalBuilder, TextInputBuilder, TextInputStyle,
} from 'discord.js';
import { userApi, api, AdminApiError } from '../services/api.js';
import { logger } from '../../backend/src/utils/logger.js';

export const IDS = {
    redeem: 'orbit:redeem',
    getScript: 'orbit:script',
    status: 'orbit:status',
    redeemModal: 'orbit:redeem_modal',
    keyField: 'license_key',
    scriptPublic: 'orbit:script:public',
    scriptPrivate: 'orbit:script:private',
};

const ACCENT = 0x7c5cff;
const RULE = '━━━━━━━━━━━━━━━━━━━━━━━━━━━';
const COLOR = { ok: 0x34d399, bad: 0xff4d6d, warn: 0xffb020, neutral: ACCENT };
const EPHEMERAL = { flags: MessageFlags.Ephemeral };

// ── The panel message ───────────────────────────────────────────────────────
export function buildPanel() {
    const embed = new EmbedBuilder()
        .setColor(ACCENT)
        .setTitle('SCRIPT AUTH')
        .setDescription([
            RULE,
            '',
            '**🔑 Redeem Key**',
            'Redeem your license key to gain access to the script.',
            '',
            '**📜 Get Script**',
            'Get your authenticated script loader.',
            '',
            '**📊 Status**',
            'Check whether the script is currently online.',
            '',
            RULE,
        ].join('\n'))
        .setFooter({ text: 'Every response is private — only you can see it.' });

    const row = new ActionRowBuilder().addComponents(
        new ButtonBuilder().setCustomId(IDS.redeem).setLabel('Redeem Key').setEmoji('🔑').setStyle(ButtonStyle.Primary),
        new ButtonBuilder().setCustomId(IDS.getScript).setLabel('Get Script').setEmoji('📜').setStyle(ButtonStyle.Success),
        new ButtonBuilder().setCustomId(IDS.status).setLabel('Check Status').setEmoji('📊').setStyle(ButtonStyle.Secondary),
    );

    return { embeds: [embed], components: [row] };
}

// ── Helpers ─────────────────────────────────────────────────────────────────
function info(title, description, color = ACCENT) {
    return new EmbedBuilder().setColor(color).setTitle(title).setDescription(description).setTimestamp(new Date());
}

/**
 * Map a backend failure onto something a user can act on without disclosing
 * which check failed. The backend already answers redeem failures with one
 * generic code for exactly that reason; this keeps the property intact in
 * Discord instead of helpfully explaining the difference.
 */
function userFacingError(err) {
    if (err?.code === 'script_offline') return '🔴 Script is currently offline.';
    if (err?.status === 429) return 'Too many attempts. Wait a moment and try again.';
    if (err?.code === 'unreachable') return 'The authentication service is unreachable. Try again shortly.';
    if (err?.code === 'forbidden') return 'Access denied.';
    return 'Invalid request.';
}

// ── Redeem ──────────────────────────────────────────────────────────────────
export async function openRedeemModal(interaction) {
    const modal = new ModalBuilder()
        .setCustomId(IDS.redeemModal)
        .setTitle('Redeem License Key')
        .addComponents(
            new ActionRowBuilder().addComponents(
                new TextInputBuilder()
                    .setCustomId(IDS.keyField)
                    .setLabel('License Key')
                    .setPlaceholder('XXXX-XXXX-XXXX-XXXX')
                    .setStyle(TextInputStyle.Short)
                    .setMinLength(16)
                    .setMaxLength(24)
                    .setRequired(true),
            ),
        );
    await interaction.showModal(modal);
}

export async function handleRedeemSubmit(interaction) {
    // Ephemeral before anything else: neither the key the user typed nor the
    // outcome should land in the channel.
    await interaction.deferReply(EPHEMERAL);

    const raw = interaction.fields.getTextInputValue(IDS.keyField) ?? '';
    // Shape check locally so an obvious typo does not spend the user's rate
    // limit budget. The backend validates and normalises independently.
    const compact = raw.toUpperCase().replace(/[^0-9A-Z]/g, '');
    if (compact.length !== 16) {
        await interaction.editReply({
            embeds: [info('Invalid request.', 'A license key looks like `XXXX-XXXX-XXXX-XXXX`.', COLOR.bad)],
        });
        return;
    }

    try {
        const res = await userApi.redeem(interaction.user, compact.match(/.{4}/g).join('-'));
        const tier = res.license?.tier ?? 'public';
        await interaction.editReply({
            embeds: [info(
                res.already_redeemed ? 'Already active' : 'Key redeemed',
                [
                    res.already_redeemed
                        ? 'This key is already active on your account.'
                        : 'Your key is now active and bound to this Discord account.',
                    '',
                    `**Tier** · ${tier}`,
                    res.license?.expires_at
                        ? `**Expires** · <t:${Math.floor(new Date(res.license.expires_at).getTime() / 1000)}:R>`
                        : '**Expires** · never',
                    '',
                    'Press **Get Script** on the panel to receive your loader.',
                ].join('\n'),
                COLOR.ok,
            )],
        });
    } catch (err) {
        if (!(err instanceof AdminApiError)) throw err;
        // One message for every failure mode: wrong key, already-bound key,
        // expired key, revoked key and blacklisted account are indistinguishable
        // from the outside.
        const msg = userFacingError(err);
        await interaction.editReply({
            embeds: [info('Redeem failed', msg === 'Invalid request.' ? 'That key could not be redeemed.' : msg, COLOR.bad)],
        });
    }
}

// ── Get Script ──────────────────────────────────────────────────────────────
export async function handleGetScript(interaction, forcedTier = null) {
    await interaction.deferReply(EPHEMERAL);

    try {
        const me = await userApi.me(interaction.user);
        const ent = me.entitlements ?? {};

        if (!ent.public && !ent.private) {
            await interaction.editReply({
                embeds: [info('Not authorised', 'No active license is bound to this account. Press **Redeem Key** first.', COLOR.warn)],
            });
            return;
        }

        // Both tiers available and no choice made yet: ask. These buttons carry
        // a tier name and nothing else.
        if (!forcedTier && ent.public && ent.private) {
            await interaction.editReply({
                embeds: [info('Get Script', 'Your license covers both. Pick one.', COLOR.neutral)],
                components: [new ActionRowBuilder().addComponents(
                    new ButtonBuilder().setCustomId(IDS.scriptPublic).setLabel('Public Script').setStyle(ButtonStyle.Secondary),
                    new ButtonBuilder().setCustomId(IDS.scriptPrivate).setLabel('Private Hub').setStyle(ButtonStyle.Primary),
                )],
            });
            return;
        }

        const tier = forcedTier ?? (ent.private ? 'private' : 'public');
        // The backend re-checks entitlement for this tier regardless of what the
        // button claimed, so a forged component cannot reach the private hub.
        const res = await userApi.getScript(interaction.user, tier);

        if (res.status !== 'online') {
            await interaction.editReply({
                embeds: [info('🔴 Script Offline', 'The script is currently offline. Your loader will work again once it is back.', COLOR.bad)],
                components: [],
            });
            return;
        }

        await interaction.editReply({
            embeds: [info(
                `📜 ${res.name}`,
                [
                    `**Tier** · ${res.tier}    **Version** · \`${res.version ?? '?'}\``,
                    '',
                    'Paste this into your executor:',
                    '```lua',
                    res.loader_snippet,
                    '```',
                    res.rotated
                        ? '⚠️ This replaced your previous script key — any loader still using the old one stops working.'
                        : null,
                    'Your script key is shown here once and cannot be read back. Press **Get Script** again to issue a new one.',
                ].filter(Boolean).join('\n'),
                COLOR.ok,
            )],
            components: [],
        });
    } catch (err) {
        if (!(err instanceof AdminApiError)) throw err;
        await interaction.editReply({
            embeds: [info('Get Script failed', userFacingError(err), COLOR.bad)],
            components: [],
        });
    }
}

// ── Status ──────────────────────────────────────────────────────────────────
export async function handleStatus(interaction) {
    await interaction.deferReply(EPHEMERAL);
    try {
        const s = await api.publicStatus();
        const online = s.script_status === 'online';
        const lines = (s.scripts ?? []).map(
            (x) => `${x.status === 'online' ? '🟢' : '🔴'} **${x.name}** · \`v${x.version}\``,
        );
        await interaction.editReply({
            embeds: [info(
                online ? '🟢 Script Online' : '🔴 Script Offline',
                lines.length ? lines.join('\n') : (online ? 'Authentication is available.' : 'Authentication is disabled.'),
                online ? COLOR.ok : COLOR.bad,
            )],
        });
    } catch (err) {
        logger.warn('panel.status_failed', { err: err.message });
        await interaction.editReply({
            embeds: [info('Status unavailable', 'Could not reach the authentication service.', COLOR.warn)],
        });
    }
}

// ── Router ──────────────────────────────────────────────────────────────────
/** Returns true when the interaction belonged to the panel and was handled. */
export async function routePanelInteraction(interaction) {
    if (interaction.isModalSubmit()) {
        if (interaction.customId !== IDS.redeemModal) return false;
        await handleRedeemSubmit(interaction);
        return true;
    }
    if (!interaction.isButton()) return false;

    switch (interaction.customId) {
        case IDS.redeem:        await openRedeemModal(interaction); return true;
        case IDS.getScript:     await handleGetScript(interaction); return true;
        case IDS.scriptPublic:  await handleGetScript(interaction, 'public'); return true;
        case IDS.scriptPrivate: await handleGetScript(interaction, 'private'); return true;
        case IDS.status:        await handleStatus(interaction); return true;
        default: return false;
    }
}
