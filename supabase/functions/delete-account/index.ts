import { withSupabase } from "npm:@supabase/server@1"

const photoBucket = "photos"
const pageSize = 100

export default {
  fetch: withSupabase({ auth: "user" }, async (request, context) => {
    if (request.method !== "POST") {
      return Response.json(
        { message: "Method not allowed" },
        { status: 405, headers: { Allow: "POST" } },
      )
    }

    const userID = context.jwtClaims.sub
    if (typeof userID !== "string" || userID.length === 0) {
      return Response.json({ message: "Unauthorized" }, { status: 401 })
    }

    try {
      // Supabase не удаляет auth-пользователя, пока тот владеет объектами
      // Storage. Сначала очищаем его приватную папку; при сбое запрос можно
      // безопасно повторить, потому что удаление файлов идемпотентно.
      while (true) {
        const { data: files, error: listError } = await context.supabaseAdmin.storage
          .from(photoBucket)
          .list(userID, { limit: pageSize })

        if (listError) throw listError
        if (!files || files.length === 0) break

        const paths = files.map((file) => `${userID}/${file.name}`)
        const { error: removeError } = await context.supabaseAdmin.storage
          .from(photoBucket)
          .remove(paths)

        if (removeError) throw removeError
        if (files.length < pageSize) break
      }

      const { error: deleteError } = await context.supabaseAdmin.auth.admin
        .deleteUser(userID)

      if (deleteError) throw deleteError

      return Response.json({ deleted: true })
    } catch (error) {
      console.error("Failed to delete account", error)
      return Response.json(
        { message: "Account deletion failed" },
        { status: 500 },
      )
    }
  }),
}
