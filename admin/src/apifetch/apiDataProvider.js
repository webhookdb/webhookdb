import humps from "humps";
import { withLifecycleCallbacks } from "ra-core";

import { apiFetchJson } from "./utils";

export default function apiDataProvider() {
  const makeFetcher = (tail) => {
    const fetcher = (resource, params) => {
      const adminurl = `/admin_api/v1/data_provider/${tail}`;
      const body = { resource, ...params };
      if (body.sort) {
        body.sort.field = humps.decamelize(body.sort.field);
      }
      return apiFetchJson(adminurl, body, { method: "POST" });
    };
    return fetcher;
  };
  const provider = {
    getList: makeFetcher("get_list"),
    getOne: makeFetcher("get_one"),
    getMany: makeFetcher("get_many"),
    getManyReference: makeFetcher("get_many_reference"),
    create: makeFetcher("create"),
    update: makeFetcher("update"),
    updateMany: makeFetcher("update_many"),
    delete: makeFetcher("delete"),
    deleteMany: makeFetcher("delete_many"),
    enqueueCurIngest: ({ curSettingsId }) =>
      apiFetchJson(
        `/admin_api/v1/actions/enqueue_cur_ingest`,
        { curSettingsId },
        { method: "POST" },
      ),
  };
  const lifecycleDataProvider = withLifecycleCallbacks(provider, [
    contractUploadedFilesCallbacks,
  ]);
  return lifecycleDataProvider;
}

const contractUploadedFilesCallbacks = {
  resource: "contract_uploaded_files",
  beforeCreate: async (params) => {
    const data = { ...params.data };
    if (data.uploadedFile) {
      data.uploadedFile.dataUrl = await convertFileToBase64(data.uploadedFile.rawFile);
      data.uploadedFile.type = data.uploadedFile.rawFile.type;
      data.uploadedFile.size = data.uploadedFile.rawFile.size;
      data.uploadedFile.name = data.uploadedFile.rawFile.name;
      delete data.uploadedFile["rawFile"];
    }

    return { ...params, data };
  },
};

/**
 * Convert a `File` object returned by the upload input into a base 64 string.
 * That's not the most optimized way to store images in production, but it's
 * enough to illustrate the idea of dataprovider decoration.
 */
const convertFileToBase64 = (file) =>
  new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
