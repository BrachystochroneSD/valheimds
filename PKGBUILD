# Maintainer: Samuel Dawant <samueld@mailo.com>

pkgname=valheimds
pkgver=1.0.0
_dstuser=valheimds
pkgrel=1
pkgdesc="Dedicated server for Valheim"
arch=('x86_64')
license=("LGPL")
depends=(
    'steamcmd'
    'screen')
optdepends=(
    "tar: needed in order to create world backups"
           )

backup=("etc/conf.d/${pkgname}")
install="${pkgname}.install"


source=("${pkgname}-backup.service"
    "${pkgname}-backup.timer"
    "${pkgname}.service"
    "${pkgname}.sysusers"
    "${pkgname}.tmpfiles"
    "${pkgname}.conf"
    "${pkgname}.sh"
       )

_game="valheimds"
_server_root="/srv/valheimds"

sha256sums=('9f8b347a1374f1d180edf5e5f7b58f56f8bc0124a8a8d25fa4ba5e52fea704a8'
            '6129a7f6a306bed810ff3f8df6d8c9252fdf3129de0df3c776accc9acdd4c207'
            'd31ccefc59ee4575bad56228f9808c3da823e74cd9d7276d44e3b9375ec4624d'
            '5ef2f169142ffb8f21d86ed9195e4e3246eadf1e7592d893761f2e1edf9a74ee'
            '600b03d0dc514ebb935f0ad3187bc1a0c02eb9d8b2bc69d1f39330d0513112df'
            '5d2a853abf60d23d1bd7b0a4aee10f89fbd125a71809addf8ca72e8cc308167a'
            'a44c45f8500738685faa2c5678a5d4283b53023ab604261bb113f2b37bd73390')

package() {
    install -Dm644 "${_game}.conf" "${pkgdir}/etc/conf.d/${_game}"
    install -Dm755 "${_game}.sh" "${pkgdir}/usr/bin/${_game}"
    install -Dm644 "${_game}.service" "${pkgdir}/usr/lib/systemd/system/${_game}.service"
    install -Dm644 "${_game}-backup.service" "${pkgdir}/usr/lib/systemd/system/${_game}-backup.service"
    install -Dm644 "${_game}-backup.timer" "${pkgdir}/usr/lib/systemd/system/${_game}-backup.timer"
    install -Dm644 "${_game}.sysusers" "${pkgdir}/usr/lib/sysusers.d/${_game}.conf"
    install -Dm644 "${_game}.tmpfiles" "${pkgdir}/usr/lib/tmpfiles.d/${_game}.conf"

    mkdir -p "${pkgdir}${_server_root}"

    # Give the group write permissions and set user or group ID on execution
    chmod g+ws "${pkgdir}${_server_root}"
}
