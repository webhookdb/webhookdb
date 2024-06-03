import get from "lodash/get";

import api from "../api";

const AUTH_TOKEN_HEADER = "Whdb-Auth-Token";

/**
 * @param {StateMachineContext} ctx
 * @param {string} postUrl
 * @param {object} postParams
 * @param {string} postParamsValueKey
 * @param {string} value
 * @return {StateMachineResponse}
 */
async function transitionStep(ctx, { postUrl, postParams, postParamsValueKey, value }) {
  const params = { ...postParams };
  params[postParamsValueKey] = value;
  const resp = await makeStepRequest(ctx, params, postUrl);
  return new StateMachineResponse(resp.data, resp);
}

/**
 * @param {StateMachineContext} ctx
 * @param {object} body
 * @param {string} url
 * @return {axios.AxiosResponse}
 */
async function makeStepRequest(ctx, body, url) {
  const cfg = {
    method: "POST",
    url,
    headers: {},
    validateStatus: (st) => st < 500,
    data: body,
  };
  if (ctx.authToken) {
    cfg.headers[AUTH_TOKEN_HEADER] = ctx.authToken;
  }
  const req = api.instance.request(cfg);
  const resp = await req;
  const errorStep = get(resp, "data.error.stateMachineStep");
  if (errorStep) {
    const errStepResponse = newStateMachine().run(ctx, errorStep);
    return errStepResponse.axiosReponse;
  }
}

class Ask {
  feedback(s) {
    console.log(s);
  }

  ask(prompt, options) {
    console.log(prompt, options);
    return "hello";
  }
}

class StateMachine {
  /**
   *
   * @param {StateMachineContext} ctx
   * @param {StateMachineStep} startingStep
   * @return {StateMachineResponse}
   */
  async run(ctx, startingStep) {
    if (startingStep.complete) {
      // If we pass in a complete step, assume the caller took car of printing the output.
      // Otherwise we can end up wish a finished step from a 422 statemachine, and then re-print the result.
      return new StateMachineResponse(startingStep, null);
    }
    let step = startingStep;
    while (true) {
      if (step.complete) {
        ctx.ask.feedback(step.output);
        return { step, axiosReponse: null };
      }
      if (!step.needsInput) {
        // Usually this is because a 422 prompt machine returned success
        return { step, axiosReponse: null };
      }
      if (step.output) {
        // If the step is the first one, so only prompts, this will be blank.
        ctx.ask.feedback(step.output);
      }
      const value = ctx.ask.ask(step.prompt, { secret: step.promptIsSecret });
      const newStep = await transitionStep(ctx, {
        postUrl: step.postToUrl,
        postParams: step.postParams,
        postParamsValueKey: step.postParamsValueKey,
        value: value,
      });
      const errorResponse = getErrorResponseBody(newStep.axiosReponse);
      if (errorResponse?.code === "validation_error") {
        // If the field that fails validation is not the one we submitted, it probably means that
        // something from the commandline failed. There's no sense re-prompting if the current field is valid,
        // since we can't fix the cause of the 400 through this transition.
        if (errorResponse.fieldErrors[step.postParamsValueKey]) {
          ctx.ask.feedback(errorResponse.message);
          ctx.ask.feedback("");
          continue;
        } else {
          return newStep;
        }
      } else if (errorResponse) {
        return newStep;
      }
      step = newStep;
      // Always print a newline after processing input, so the next step output
      // has a blank line after the input.
      ctx.ask.feedback("");
    }
  }
}

/**
 * @return {StateMachine}
 */
export function newStateMachine() {
  return new StateMachine();
}

/**
 * @typedef StateMachineStep
 * @property {string} message
 * @property {boolean} needsInput
 * @property {string} prompt
 * @property {boolean} promptIsSecret
 * @property {string} postToUrl
 * @property {object} postParams
 * @property {string} postParamsValueKey
 * @property {boolean} complete
 * @property {string} output
 * @property {object} extras
 */

class StateMachineResponse {
  /**
   * @param {StateMachineStep} step
   * @param {axios.AxiosResponse} axiosResponse
   */
  constructor(step, axiosResponse) {
    this.step = step;
    this.axiosReponse = axiosResponse;
  }
}

class StateMachineContext {
  /**
   * @param {string} authToken
   * @param {Ask} ask
   */
  constructor({ authToken, ask }) {
    this.authToken = authToken || "";
    this.ask = ask;
  }
}

/**
 * @param {axios.AxiosResponse} r
 * @return {ErrorResponse|null}
 */
function getErrorResponseBody(r) {
  if (r && r.data && r.data.error) {
    return r.data;
  }
  return null;
}

/**
 * @typedef ErrorResponse
 * @property {string} error.message
 * @property {string} error.code
 * @property {number} error.status
 * @property {Array<string>} error.errors
 * @property {Map} error.fieldErrors
 * @property {StateMachineStep} error.stateMachineStep
 */
